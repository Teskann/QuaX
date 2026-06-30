import 'dart:async';
import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/_video_controls.dart';
import 'package:quax/tweet/video_audio_focus.dart';
import 'package:quax/tweet/video_controller_pool.dart';
import 'package:quax/tweet/video_quality.dart';
import 'package:quax/utils/iterables.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Picks orientation from the video's shape so a portrait video isn't forced
// into landscape like media_kit's `defaultEnterNativeFullscreen` does.
Future<void> _enterFullscreen(double aspectRatio) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return defaultEnterNativeFullscreen();
  }
  try {
    final portrait = aspectRatio < 1.0;
    await Future.wait([
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky, overlays: []),
      SystemChrome.setPreferredOrientations(portrait
          ? [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
          : [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]),
    ]);
  } catch (_) {}
}

class TweetVideoUrls {
  final String streamUrl;
  final String? downloadUrl;
  final List<TweetVideoQuality> qualities;

  TweetVideoUrls(this.streamUrl, this.downloadUrl, {this.qualities = const []});
}

class TweetVideoMetadata {
  final double aspectRatio;
  final String? imageUrl;
  final Future<TweetVideoUrls> Function() streamUrlsBuilder;

  TweetVideoMetadata(this.aspectRatio, this.imageUrl, this.streamUrlsBuilder);

  static Future<TweetVideoUrls> Function() streamUrlsBuilderFromVariants(List<Variant> variants) {
    // Use progressive MP4, not X's HLS master playlist (variants[0]): libmpv
    // plays the .m3u8 poorly (delayed start, bad seek, phantom subtitle tracks).
    // Fall back to variants[0] only when no MP4 exists (e.g. live broadcasts).
    var mp4Variants = variants
        .where((e) => e.bitrate != null)
        .where((e) => e.url != null)
        .where((e) => e.contentType == 'video/mp4')
        .sorted((a, b) => -(a.bitrate!.compareTo(b.bitrate!)))
        .toList();

    var qualities =
        mp4Variants.map((e) => TweetVideoQuality(e.url!, _qualityLabel(e.url!, e.bitrate))).toList();

    var mp4Url = qualities.isNotEmpty ? qualities.first.url : null;
    var streamUrl = mp4Url ?? variants[0].url!;

    return () async => TweetVideoUrls(streamUrl, mp4Url, qualities: qualities);
  }

  // Resolution tag from X's MP4 URL path (`.../1280x720/...`), else the bitrate.
  static String _qualityLabel(String url, int? bitrate) {
    var match = RegExp(r'/(\d+)x(\d+)/').firstMatch(url);
    if (match != null) {
      return '${match.group(2)}p';
    }
    if (bitrate != null) {
      return '${(bitrate / 1000000).toStringAsFixed(1)} Mbps';
    }
    return '—';
  }

  factory TweetVideoMetadata.fromMedia(Media media) {
    var aspectRatio = media.videoInfo?.aspectRatio == null
        ? 1.0
        : media.videoInfo!.aspectRatio![0] / media.videoInfo!.aspectRatio![1];

    var variants = media.videoInfo?.variants ?? [];
    var imageUrl = media.mediaUrlHttps!;

    return TweetVideoMetadata(aspectRatio, imageUrl, streamUrlsBuilderFromVariants(variants));
  }
}

class TweetVideo extends StatefulWidget {
  final String username;
  final bool loop;
  final TweetVideoMetadata metadata;
  final bool alwaysPlay;
  final bool disableControls;
  final String? tweetId;
  final int mediaIndex;

  const TweetVideo({
    super.key,
    required this.username,
    required this.loop,
    required this.metadata,
    this.alwaysPlay = false,
    this.disableControls = false,
    this.tweetId,
    this.mediaIndex = 0,
  });

  @override
  State<StatefulWidget> createState() => _TweetVideoState();
}

class _TweetVideoState extends State<TweetVideo> {
  VideoControllerPool? _pool;
  PooledVideo? _pooled;
  Future<PooledVideo>? _acquireFuture;
  bool _ownsControllers = false;
  bool _holdsPoolRef = false;

  bool _autoPlay = false;
  bool _userRequestedPlay = false;
  bool _isFullscreen = false;
  bool _playbackError = false;
  bool _firstFrameRendered = false;
  bool _posterGone = false;
  bool _subtitlesEnabled = false;
  bool _prefLoop = false;
  bool _mixWithOthers = false;
  int _autoRetries = 0;
  final Key _visibilityKey = UniqueKey();
  double _lastVisibleFraction = 0.0;
  Timer? _pauseTimer;
  StreamSubscription<double>? _muteSub;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<bool>? _playingSub;

  String? get _cacheKey => widget.tweetId == null ? null : '${widget.tweetId}:${widget.mediaIndex}';

  @override
  void initState() {
    super.initState();
    try {
      _pool = context.read<VideoControllerPool>();
    } on ProviderNotFoundException {
      _pool = null;
    }
  }

  // Default variant from [optionMediaSize]; qualities are sorted highest-first.
  static String _defaultQualityUrl(TweetVideoUrls urls, String mediaSize) {
    final q = urls.qualities;
    if (q.isEmpty) return urls.streamUrl;
    final i = switch (mediaSize) {
      'thumb' => q.length - 1,
      'small' => (q.length * 3) ~/ 4,
      'medium' => q.length ~/ 2,
      _ => 0,
    };
    return q[i.clamp(0, q.length - 1)].url;
  }

  Future<PooledVideo> _createPooled(bool prefLoop, bool startMuted, String mediaSize) async {
    var urls = await widget.metadata.streamUrlsBuilder();
    var streamUrl = _defaultQualityUrl(urls, mediaSize);

    var player = mk.Player();
    var videoController = VideoController(player);

    var platform = player.platform;
    if (platform is mk.NativePlayer) {
      // AAudio sounds better than the default opensles and avoids the
      // audiotrack JNI crash; falls back to opensles below Android 8.
      await platform.setProperty('ao', 'aaudio,opensles');
      // System MediaCodec decoders, with libmpv's software decoders as fallback.
      await platform.setProperty('hwdec', 'mediacodec-copy');
    }

    await player.setPlaylistMode(
        (widget.loop || prefLoop) ? mk.PlaylistMode.single : mk.PlaylistMode.none);
    await player.setVolume(startMuted ? 0.0 : 100.0);
    await player.open(mk.Media(streamUrl), play: widget.alwaysPlay || _userRequestedPlay);

    return PooledVideo(
      player: player,
      videoController: videoController,
      downloadUrl: urls.downloadUrl,
      qualities: urls.qualities,
      currentStreamUrl: streamUrl,
      pausableByPolicy: !widget.disableControls,
    );
  }

  Future<PooledVideo> _acquire(bool prefLoop) async {
    var startMuted = context.read<VideoContextState>().isMuted;
    var mediaSize = PrefService.of(context, listen: false).get(optionMediaSize);
    create() => _createPooled(prefLoop, startMuted, mediaSize);

    final key = _cacheKey;
    final pool = _pool;
    PooledVideo pooled;
    if (key == null || pool == null) {
      _ownsControllers = true;
      pooled = await create();
      if (!mounted) {
        await pooled.dispose();
        return pooled;
      }
    } else {
      pooled = await pool.acquire(key, create);
      if (!mounted) {
        pool.release(key);
        return pooled;
      }
      _holdsPoolRef = true;
    }

    _pooled = pooled;
    _attachListeners(pooled);
    return pooled;
  }

  void _attachListeners(PooledVideo pooled) {
    var model = context.read<VideoContextState>();
    pooled.player.setVolume(model.isMuted ? 0.0 : 100.0);
    _muteSub = pooled.player.stream.volume.listen((volume) {
      if (!mounted) return;
      model.setIsMuted(volume);
    });
    _playingSub = pooled.player.stream.playing.listen((playing) {
      if (!mounted) return;
      if (widget.disableControls) return;
      if (playing) {
        _autoRetries = 0;
        if (_playbackError) setState(() => _playbackError = false);
        _pool?.pauseOthers(pooled);
        VideoAudioFocus.instance.onStartedPlaying(pooled.player, mixWithOthers: _mixWithOthers);
      } else {
        VideoAudioFocus.instance.onStoppedPlaying(pooled.player);
      }
    });
    _errorSub = pooled.player.stream.error.listen((_) {
      if (!mounted) return;
      // GIFs must keep looping — retry silently instead of showing an error.
      if (widget.disableControls) {
        if (_autoRetries < 3) {
          _autoRetries++;
          _restartVideo(_prefLoop);
        }
        return;
      }
      // Ignore transient mid-playback errors libmpv recovers from; only a video
      // that never rendered a frame is a real failure.
      if (!_firstFrameRendered) setState(() => _playbackError = true);
    });

    pooled.videoController.waitUntilFirstFrameRendered.then((_) {
      if (mounted) setState(() => _firstFrameRendered = true);
    });
  }

  void _detachListeners() {
    _muteSub?.cancel();
    _muteSub = null;
    _errorSub?.cancel();
    _errorSub = null;
    _playingSub?.cancel();
    _playingSub = null;
  }

  void _onVisibilityChanged(VisibilityInfo info, PooledVideo pooled) {
    if (!mounted) return;
    final key = _cacheKey;
    final wasVisible = _lastVisibleFraction >= 0.5;
    final isVisible = info.visibleFraction >= 0.5;
    _lastVisibleFraction = info.visibleFraction;

    if (isVisible) {
      if (key != null) _pool?.markVisible(key, this);
      _pauseTimer?.cancel();
      _pauseTimer = null;
      if (_autoPlay && !wasVisible && !pooled.player.state.playing) {
        pooled.player.play();
      }
    } else if (!widget.alwaysPlay && wasVisible) {
      if (key != null) _pool?.markHidden(key, this);
      _pauseTimer ??= Timer(const Duration(milliseconds: 100), () {
        _pauseTimer = null;
        if (key != null && (_pool?.anyVisible(key) ?? false)) return;
        if (mounted && !_isFullscreen) {
          pooled.player.pause();
        }
      });
    }
  }

  Future<void> _restartVideo(bool prefLoop) async {
    _detachListeners();
    final key = _cacheKey;
    if (key != null && _pool != null) {
      if (_holdsPoolRef) {
        _pool!.release(key);
        _holdsPoolRef = false;
      }
      _pool!.invalidate(key);
    } else {
      await _pooled?.player.pause();
      await _pooled?.dispose();
    }

    setState(() {
      _pooled = null;
      _acquireFuture = null;
      _playbackError = false;
      _firstFrameRendered = false;
      _posterGone = false;
    });
  }

  void _toggleSubtitles(PooledVideo pooled) {
    final enable = !_subtitlesEnabled;
    setState(() => _subtitlesEnabled = enable);
    if (enable) {
      final subs = pooled.player.state.tracks.subtitle;
      final track = subs.firstWhere(
        (t) => t.id != 'no' && t.id != 'auto',
        orElse: () => mk.SubtitleTrack.auto(),
      );
      pooled.player.setSubtitleTrack(track);
    } else {
      pooled.player.setSubtitleTrack(mk.SubtitleTrack.no());
    }
  }

  Widget _buildVideo(PooledVideo pooled, bool prefBackgroundPlayback) {
    final accent = Theme.of(context).colorScheme.secondary;
    final video = Video(
      controller: pooled.videoController,
      aspectRatio: widget.metadata.aspectRatio,
      controls: widget.disableControls
          ? null
          : (state) => QuaxControls(
                pooled: pooled,
                username: widget.username,
                allowMuting: true,
                accentColor: accent,
                subtitlesEnabled: _subtitlesEnabled,
                onToggleSubtitles: () => _toggleSubtitles(pooled),
              ),
      wakelock: !widget.disableControls,
      pauseUponEnteringBackgroundMode: !prefBackgroundPlayback,
      subtitleViewConfiguration: SubtitleViewConfiguration(visible: _subtitlesEnabled),
      onEnterFullscreen: () async {
        _isFullscreen = true;
        await _enterFullscreen(widget.metadata.aspectRatio);
      },
      onExitFullscreen: () async {
        _isFullscreen = false;
        await defaultExitNativeFullscreen();
      },
    );

    if (_posterGone) {
      return video;
    }

    // Poster + spinner over the always-painting video texture, fading out on the
    // first frame so there's no black flash on the swap.
    return Stack(
      fit: StackFit.expand,
      children: [
        video,
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _firstFrameRendered ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            onEnd: () {
              if (_firstFrameRendered && !_posterGone) setState(() => _posterGone = true);
            },
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                if (widget.metadata.imageUrl != null)
                  Image.network(widget.metadata.imageUrl!, fit: BoxFit.cover),
                if (!widget.disableControls) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context);
    final prefLoop = prefs.get(optionMediaDefaultLoop);
    final prefAutoPlay = prefs.get(optionMediaDefaultAutoPlay);
    final prefBackgroundPlayback = prefs.get(optionMediaBackgroundPlayback);
    _prefLoop = prefLoop;
    _mixWithOthers = prefs.get(optionMediaAllowBackgroundPlayOtherApps);

    final key = _cacheKey;
    final alreadyCached = key != null && (_pool?.contains(key) ?? false);

    if (!prefAutoPlay && !widget.alwaysPlay && !_userRequestedPlay && !alreadyCached) {
      return GestureDetector(
        onTap: () => setState(() => _userRequestedPlay = true),
        child: AspectRatio(
          aspectRatio: widget.metadata.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.metadata.imageUrl != null)
                Positioned.fill(child: Image.network(widget.metadata.imageUrl!, fit: BoxFit.cover)),
              FritterCenterPlayButton(
                backgroundColor: Colors.black54,
                iconColor: Colors.white,
                show: true,
                isPlaying: false,
                isFinished: false,
                onPressed: () => setState(() => _userRequestedPlay = true),
              ),
            ],
          ),
        ),
      );
    }

    _autoPlay = prefAutoPlay;
    _acquireFuture ??= _acquire(prefLoop);

    return FutureBuilder(
      future: _acquireFuture,
      builder: (context, snapshot) {
        final hasError = snapshot.hasError || _playbackError;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final pooled = _pooled ?? (key != null ? _pool?.peek(key) : null);
        final hasVideo = pooled != null;

        if (isLoading && !hasVideo) {
          return AspectRatio(
            aspectRatio: widget.metadata.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.metadata.imageUrl != null)
                  Positioned.fill(child: Image.network(widget.metadata.imageUrl!, fit: BoxFit.cover)),
                const CircularProgressIndicator(),
              ],
            ),
          );
        }

        if (hasError && !_firstFrameRendered) {
          return AspectRatio(
            aspectRatio: widget.metadata.aspectRatio,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 12),
                  Text(L10n.of(context).failed_to_load_video),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => _restartVideo(prefLoop),
                    child: Text(L10n.of(context).restart_video_player),
                  ),
                ],
              ),
            ),
          );
        }

        return AspectRatio(
          aspectRatio: widget.metadata.aspectRatio,
          child: hasVideo
              ? VisibilityDetector(
                  key: _visibilityKey,
                  onVisibilityChanged: (info) => _onVisibilityChanged(info, pooled),
                  child: _buildVideo(pooled, prefBackgroundPlayback))
              : const SizedBox.shrink(),
        );
      },
    );
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _detachListeners();
    final key = _cacheKey;
    if (key != null) _pool?.markHidden(key, this);
    // Keep the controller alive across the native fullscreen handoff; just don't
    // dispose/release it here. Detaching listeners and releasing the pool ref,
    // though, is always safe (the pool owns the player) and must happen even in
    // fullscreen, or this widget leaks its subscriptions and pins the entry.
    if (!_isFullscreen) {
      if (_ownsControllers) {
        _pooled?.dispose();
      } else if (key != null && _holdsPoolRef) {
        _pool?.release(key);
        _holdsPoolRef = false;
      }
    }
    super.dispose();
  }
}

/// Mute is an app-wide toggle: muting one video keeps the next one muted, on
/// every screen. Tweet tiles each sit under their own [VideoContextState]
/// provider, so a single shared [ValueNotifier] is the source of truth and every
/// per-scope instance forwards its changes — that way all scopes stay in sync and
/// rebuild together (a plain static field only notified the one scope that fired).
class VideoContextState extends ChangeNotifier {
  static final ValueNotifier<bool> _muted = ValueNotifier(false);
  static bool _initialised = false;

  VideoContextState(bool initialMuted) {
    // The pref is only the initial default; once set, mute is user-controlled.
    if (!_initialised) {
      _initialised = true;
      _muted.value = initialMuted;
    }
    _muted.addListener(notifyListeners);
  }

  @override
  void dispose() {
    _muted.removeListener(notifyListeners);
    super.dispose();
  }

  bool get isMuted => _muted.value;

  void setIsMuted(double volume) {
    final muted = _muted.value;
    if (muted && volume > 0 || !muted && volume == 0) {
      _muted.value = !muted;
    }
  }
}
