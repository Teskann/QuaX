import 'dart:async';
import 'dart:math';

import 'package:better_player_plus/better_player_plus.dart'
    hide VisibilityDetector, VisibilityDetectorController, VisibilityInfo;
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/_video_controls.dart';
import 'package:quax/tweet/video_controller_pool.dart';
import 'package:quax/tweet/video_player_budget.dart';
import 'package:quax/tweet/video_quality.dart';
import 'package:quax/tweet/video_wakelock.dart';
import 'package:quax/utils/iterables.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Disk cache so replaying a finished video, scrolling back to it, or a GIF
/// looping reads from disk instead of re-downloading — the player keeps no
/// back-buffer, so without this a seek to 0 re-fetches from the network.
const _videoCacheConfiguration = BetterPlayerCacheConfiguration(
  useCache: true,
  maxCacheSize: 256 * 1024 * 1024,
  maxCacheFileSize: 50 * 1024 * 1024,
);

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
    // Use the progressive MP4 variants (highest bitrate first), not X's HLS
    // master playlist (variants[0]): the MP4 list is what powers the in-player
    // quality picker. Fall back to variants[0] only when no MP4 exists (e.g.
    // live broadcasts), which the player handles over HLS natively.
    var mp4Variants = variants
        .where((e) => e.bitrate != null)
        .where((e) => e.url != null)
        .where((e) => e.contentType == 'video/mp4')
        .sorted((a, b) => -(a.bitrate!.compareTo(b.bitrate!)))
        .toList();

    var qualities =
        mp4Variants.map((e) => TweetVideoQuality(e.url!, _qualityLabel(e.url!, e.bitrate), bitrate: e.bitrate)).toList();

    var mp4Url = qualities.isNotEmpty ? qualities.first.url : null;
    var streamUrl = mp4Url ?? variants.firstWhereOrNull((e) => e.url != null)?.url ?? '';

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

  // GIFs play on their own, silently and on a loop, all over the timeline.
  bool get keepsScreenAwake => !disableControls;

  @override
  State<StatefulWidget> createState() => _TweetVideoState();
}

class _TweetVideoState extends State<TweetVideo> with WidgetsBindingObserver {
  VideoControllerPool? _pool;
  PooledVideo? _pooled;
  Future<PooledVideo>? _acquireFuture;
  bool _ownsControllers = false;
  bool _holdsPoolRef = false;

  bool _autoPlay = false;
  bool _userRequestedPlay = false;
  bool _playbackError = false;
  bool _firstFrameRendered = false;
  bool _posterGone = false;
  bool _prefBackground = true;
  final Key _visibilityKey = UniqueKey();
  double _visibleFraction = 0.0;
  bool _visibilityReported = false;
  bool _assumedVisible = false;
  double _lastVisibleFraction = 0.0;
  // The pool took this player back for a newer one: wait for this video to
  // leave the screen and come back before asking for another.
  bool _evicted = false;
  bool _retriedAfterDecoderFailure = false;
  Timer? _pauseTimer;
  void Function(BetterPlayerEvent)? _onEvent;

  String? get _cacheKey => widget.tweetId == null ? null : '${widget.tweetId}:${widget.mediaIndex}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _pool = context.read<VideoControllerPool>();
    } on ProviderNotFoundException {
      _pool = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // With background playback off, pause when the app leaves the foreground.
    if (_prefBackground) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (_pooled?.isPlaying ?? false) _pooled?.controller.pause();
    }
  }

  // Default variant from [optionMediaVideoQuality]; qualities are sorted highest-first.
  static String _defaultQualityUrl(TweetVideoUrls urls, String quality) {
    final q = urls.qualities;
    if (q.isEmpty) return urls.streamUrl;
    final i = switch (quality) {
      'thumb' => q.length - 1,
      'small' => (q.length * 3) ~/ 4,
      'medium' => q.length ~/ 2,
      _ => 0,
    };
    return q[i.clamp(0, q.length - 1)].url;
  }

  // Map the prefetch pref to the player's buffering. These are targets, not a
  // hard cap (it loads in byte-sized chunks), so the buffered amount is only
  // approximate — min == max keeps it close. The player can't be given a byte
  // limit, so the time is capped by what fits in videoBufferBytesPerPlayer at
  // the clip's highest bitrate (the user may switch to it): buffering whole clips
  // filled the Java heap and crashed the app.
  static BetterPlayerBufferingConfiguration _bufferingFor(int prefetchSeconds, int? bitrate) {
    final cap = maxBufferMsFor(bitrate);
    final ms = prefetchSeconds > 0 ? min(prefetchSeconds * 1000, cap) : cap;
    return BetterPlayerBufferingConfiguration(
      minBufferMs: ms,
      maxBufferMs: ms,
      bufferForPlaybackMs: min(ms, 2500),
      bufferForPlaybackAfterRebufferMs: min(ms, 5000),
    );
  }

  Future<PooledVideo> _createPooled(bool prefLoop, bool startMuted, String quality,
      int prefetchSeconds, bool mixWithOthers) async {
    final urls = await widget.metadata.streamUrlsBuilder();
    final streamUrl = _defaultQualityUrl(urls, quality);
    final username = widget.username;
    final qualities = urls.qualities;
    final downloadUrl = urls.downloadUrl;

    final controlsConfiguration = widget.disableControls
        ? const BetterPlayerControlsConfiguration(showControls: false)
        : BetterPlayerControlsConfiguration(
            playerTheme: BetterPlayerTheme.custom,
            customControlsBuilder: (controller, onControlsVisibilityChanged, config) => QuaxControls(
              controller: controller,
              username: username,
              qualities: qualities,
              downloadUrl: downloadUrl,
            ),
          );

    final configuration = BetterPlayerConfiguration(
      aspectRatio: widget.metadata.aspectRatio,
      fit: BoxFit.contain,
      autoPlay: widget.alwaysPlay || _userRequestedPlay,
      looping: widget.loop || prefLoop,
      // The pool owns the controller's lifetime, not the widget.
      autoDispose: false,
      // The app owns lifecycle: its own visibility detector drives play/pause and
      // the single-audio policy. Letting the library also handle lifecycle makes
      // the two fight (auto-resume that bypasses pauseOthers). Background-off is
      // enforced by pausing on app background in didChangeAppLifecycleState.
      handleLifecycle: false,
      // GIFs may let the screen sleep; a real video keeps it awake while playing.
      allowedScreenSleep: widget.disableControls,
      autoDetectFullscreenDeviceOrientation: true,
      autoDetectFullscreenAspectRatio: true,
      controlsConfiguration: controlsConfiguration,
      // The player's own error UI is suppressed; errors surface via events and
      // the widget's own retry affordance.
      errorBuilder: (context, error) => const SizedBox.shrink(),
    );

    final controller = BetterPlayerController(configuration);
    final dataSource = BetterPlayerDataSource.network(
      streamUrl,
      cacheConfiguration: _videoCacheConfiguration,
      bufferingConfiguration: _bufferingFor(prefetchSeconds, qualities.firstOrNull?.bitrate),
    );
    final mixWithOtherApps = widget.disableControls || mixWithOthers;
    final ready = controller.setupDataSource(dataSource).then((_) async {
      // Silent looping GIFs must never grab audio focus and pause other apps.
      controller.setMixWithOthers(mixWithOtherApps);
      await controller.setVolume(startMuted ? 0.0 : 1.0);
    });

    return PooledVideo(
      controller: controller,
      downloadUrl: downloadUrl,
      qualities: qualities,
      ready: ready,
      pausableByPolicy: !widget.disableControls,
    );
  }

  Future<PooledVideo> _acquire(bool prefLoop) async {
    final prefs = PrefService.of(context, listen: false);
    final startMuted = context.read<VideoContextState>().isMuted;
    final quality = prefs.get(optionMediaVideoQuality);
    final prefetchSeconds = prefs.get<int>(optionMediaVideoPrefetchSeconds) ?? 0;
    final mixWithOthers = prefs.get<bool>(optionMediaAllowBackgroundPlayOtherApps) ?? false;
    create() => _createPooled(prefLoop, startMuted, quality, prefetchSeconds, mixWithOthers);

    final key = _cacheKey;
    final pool = _pool;
    PooledVideo pooled;
    if (key == null || pool == null) {
      _ownsControllers = true;
      pooled = await create();
      try {
        await pooled.ready;
      } catch (_) {
        await pooled.dispose();
        rethrow;
      }
      if (!mounted) {
        await pooled.dispose();
        return pooled;
      }
    } else {
      try {
        pooled = await pool.acquire(key, this, create, onEvicted: _onEvicted);
      } catch (error) {
        pool.release(key, this);
        if (mounted && !_retriedAfterDecoderFailure && isDecoderFailure('$error')) _retryAfterFreeingAPlayer();
        rethrow;
      }
      if (!mounted) {
        pool.release(key, this);
        return pooled;
      }
      // Evicted while it was being built: _onEvicted already reset this widget.
      if (!pool.holds(key, this)) return pooled;
      _holdsPoolRef = true;
    }

    _pooled = pooled;
    _attachListeners(pooled);
    if (_visibilityReported) _updatePlayback(_visibleFraction, pooled);
    return pooled;
  }

  // Reused before this widget was reported on screen (the tweet that was just
  // opened, or rebuilt): count it as visible until then, or the widgets it comes
  // from pause it when they hide or go. Done while building, so before their
  // end-of-frame pause.
  void _assumeVisible(String key) {
    _pool?.markVisible(key, this);
    _assumedVisible = true;
  }

  void _onEvicted() {
    _detachListeners();
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _holdsPoolRef = false;
    _evicted = true;
    if (mounted) setState(_resetPlayer);
  }

  void _resetPlayer() {
    _pooled = null;
    _acquireFuture = null;
    _playbackError = false;
    _firstFrameRendered = false;
    _posterGone = false;
    _lastVisibleFraction = 0.0;
    _assumedVisible = false;
  }

  // No decoder or memory left for this player: free the oldest one and try
  // again, only once, so a failing video can't keep spawning decoders.
  void _retryAfterFreeingAPlayer() {
    final key = _cacheKey;
    if (key == null || _pool == null) return;
    _retriedAfterDecoderFailure = true;
    _pool!.evictOldest(except: key);
    _restartVideo();
  }

  void _attachListeners(PooledVideo pooled) {
    final controller = pooled.controller;
    final model = context.read<VideoContextState>();
    controller.setVolume(model.isMuted ? 0.0 : 1.0);

    // A reused pooled controller is already initialized — skip the poster fade.
    if (pooled.isInitialized) {
      _firstFrameRendered = true;
      _posterGone = true;
    }

    _onEvent = (event) {
      if (!mounted) return;
      switch (event.betterPlayerEventType) {
        case BetterPlayerEventType.initialized:
          if (!_firstFrameRendered) setState(() => _firstFrameRendered = true);
          break;
        case BetterPlayerEventType.play:
          if (_playbackError) setState(() => _playbackError = false);
          _pool?.pauseOthers(pooled);
          if (widget.keepsScreenAwake) VideoWakelock.acquire(this);
          break;
        case BetterPlayerEventType.pause:
        case BetterPlayerEventType.finished:
          VideoWakelock.release(this);
          break;
        case BetterPlayerEventType.hideFullscreen:
          // Leaving fullscreen, the player disables the wakelock itself even
          // though playback goes on inline, so put it back once it has.
          WidgetsBinding.instance.addPostFrameCallback((_) => VideoWakelock.reapply());
          break;
        case BetterPlayerEventType.setVolume:
          final volume = event.parameters?['volume'] as double?;
          if (volume != null) model.setIsMuted(volume);
          break;
        case BetterPlayerEventType.exception:
          // Never recreate the player in a loop on error. Under hardware-decoder
          // pressure a codec init fails with NO_MEMORY; recreating spawns another
          // decoder and floods the heap with exceptions until the process
          // OOM-crashes. A decoder failure gets a single retry after freeing the
          // oldest player; after that a GIF just shows its poster and a video the
          // retry affordance. The player already retries recoverable errors itself.
          VideoWakelock.release(this);
          if (!_firstFrameRendered &&
              !_retriedAfterDecoderFailure &&
              isDecoderFailure(event.parameters?['exception'] as String?)) {
            _retryAfterFreeingAPlayer();
            break;
          }
          if (!widget.disableControls && !_firstFrameRendered) {
            setState(() => _playbackError = true);
          }
          break;
        default:
          break;
      }
    };
    controller.addEventsListener(_onEvent!);
  }

  void _detachListeners() {
    VideoWakelock.release(this);
    if (_onEvent != null) {
      _pooled?.controller.removeEventsListener(_onEvent!);
      _onEvent = null;
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted) return;
    final wasInView = _visibleFraction > 0;
    _visibleFraction = info.visibleFraction;
    _visibilityReported = true;
    final inView = _visibleFraction > 0;
    if (!inView) {
      _evicted = false;
      _retriedAfterDecoderFailure = false;
    }
    // Players are only created once on screen: the list also builds tiles
    // that are off screen, and each player is heavy.
    if (inView != wasInView) setState(() {});
    final pooled = _pooled;
    if (pooled != null) _updatePlayback(_visibleFraction, pooled);
    _assumedVisible = false;
  }

  void _updatePlayback(double visibleFraction, PooledVideo pooled) {
    final key = _cacheKey;
    final wasVisible = _lastVisibleFraction >= 0.5;
    final isVisible = visibleFraction >= 0.5;
    _lastVisibleFraction = visibleFraction;

    if (isVisible) {
      if (key != null) _pool?.markVisible(key, this);
      _pauseTimer?.cancel();
      _pauseTimer = null;
      if (_autoPlay && !wasVisible && !pooled.isPlaying) {
        pooled.controller.play();
      }
    } else if (wasVisible || _assumedVisible) {
      if (key != null) _pool?.markHidden(key, this);
      if (widget.alwaysPlay) return;
      _pauseTimer ??= Timer(const Duration(milliseconds: 100), () {
        _pauseTimer = null;
        if (key != null && (_pool?.anyVisible(key) ?? false)) return;
        if (mounted && !pooled.controller.isFullScreen) {
          pooled.controller.pause();
        }
      });
    }
  }

  Future<void> _restartVideo() async {
    _detachListeners();
    final key = _cacheKey;
    if (key != null && _pool != null) {
      if (_holdsPoolRef) {
        _pool!.release(key, this);
        _holdsPoolRef = false;
      }
      _pool!.invalidate(key);
    } else {
      _pooled?.pause();
      await _pooled?.dispose();
    }

    if (mounted) setState(_resetPlayer);
  }

  Widget _buildVideo(PooledVideo pooled) {
    final video = BetterPlayer(controller: pooled.controller);

    if (_posterGone) {
      return video;
    }

    // Poster + spinner over the video, fading out on the first frame so there's
    // no flash on the swap.
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
                // A GIF shown static (still buffering, or no decoder available)
                // gets a "GIF" label; it fades out with the poster once it plays.
                if (widget.disableControls)
                  const Positioned(left: 6, bottom: 6, child: GifBadge()),
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
    _prefBackground = prefs.get<bool>(optionMediaBackgroundPlayback) ?? true;

    final key = _cacheKey;
    final alreadyCached = key != null && (_pool?.contains(key) ?? false);

    final Widget content;
    if (!prefAutoPlay && !widget.alwaysPlay && !_userRequestedPlay && !alreadyCached) {
      content = _buildTapToPlay();
    } else {
      _autoPlay = prefAutoPlay;
      final cached = key == null ? null : _pool?.peek(key);
      // A player already in the pool costs nothing to reuse: no need to wait
      // for this widget to be reported on screen, nor to show the poster.
      if (_acquireFuture == null && !_evicted && (_visibleFraction > 0 || cached != null)) {
        if (cached != null && !_visibilityReported) _assumeVisible(key!);
        _acquireFuture = _acquire(prefLoop);
      }
      if (_pooled == null && (cached?.isInitialized ?? false)) {
        _firstFrameRendered = true;
        _posterGone = true;
      }
      content = _acquireFuture == null ? _buildIdle() : _buildPlayer(key);
    }

    return VisibilityDetector(key: _visibilityKey, onVisibilityChanged: _onVisibilityChanged, child: content);
  }

  void _requestPlay() => setState(() {
        _userRequestedPlay = true;
        _evicted = false;
      });

  Widget _buildTapToPlay() {
    return GestureDetector(
      onTap: _requestPlay,
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
              onPressed: _requestPlay,
            ),
          ],
        ),
      ),
    );
  }

  // No player yet: still off screen, or given back to the pool.
  Widget _buildIdle() {
    if (!_evicted) return _buildPoster(loading: true);
    return widget.disableControls ? _buildPoster(loading: false) : _buildTapToPlay();
  }

  Widget _buildPoster({required bool loading}) {
    return AspectRatio(
      aspectRatio: widget.metadata.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.metadata.imageUrl != null)
            Positioned.fill(child: Image.network(widget.metadata.imageUrl!, fit: BoxFit.cover)),
          if (loading) const CircularProgressIndicator(),
          if (!loading) const Positioned(left: 6, bottom: 6, child: GifBadge()),
        ],
      ),
    );
  }

  Widget _buildPlayer(String? key) {
    return FutureBuilder(
      future: _acquireFuture,
      builder: (context, snapshot) {
        final hasError = snapshot.hasError || _playbackError;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final pooled = _pooled ?? (key != null ? _pool?.peek(key) : null);
        final hasVideo = pooled != null;

        if (isLoading && !hasVideo) return _buildPoster(loading: true);

        if (hasError && !_firstFrameRendered) {
          return AspectRatio(
            aspectRatio: widget.metadata.aspectRatio,
            // FittedBox so the error block scales down instead of overflowing in
            // short/narrow video areas (a wide clip in the feed, a grid cell...).
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white, size: 48),
                      const SizedBox(height: 12),
                      Text(L10n.of(context).failed_to_load_video),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _restartVideo,
                        child: Text(L10n.of(context).restart_video_player),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return AspectRatio(
          aspectRatio: widget.metadata.aspectRatio,
          child: hasVideo ? _buildVideo(pooled) : const SizedBox.shrink(),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pauseTimer?.cancel();
    _detachListeners();
    final key = _cacheKey;
    if (key != null) _pool?.markHidden(key, this);
    // Keep the controller alive across the fullscreen route; just don't
    // dispose/release it here. Detaching listeners and releasing the pool ref,
    // though, is always safe (the pool owns the controller) and must happen even
    // in fullscreen, or this widget leaks its subscriptions and pins the entry.
    final fullscreen = _pooled?.controller.isFullScreen ?? false;
    if (!fullscreen) {
      if (_ownsControllers) {
        _pooled?.dispose();
      } else if (key != null && _holdsPoolRef) {
        // A fast fling can dispose this widget before the debounced pause timer
        // fires; releasing the pool ref alone leaves the player running off-screen.
        // Pause it, unless the same video is still on screen in another widget.
        // Not right now: pausing rebuilds the other widgets showing this player,
        // which is forbidden while the tree is being finalized, and a widget
        // showing it again (the feed, back from the tweet) has yet to report it.
        final pooled = _pooled;
        final pool = _pool;
        if (!widget.alwaysPlay && pooled != null) {
          Timer(VisibilityDetectorController.instance.updateInterval + const Duration(milliseconds: 100), () {
            if (!(pool?.anyVisible(key) ?? false)) pooled.pause();
          });
        }
        _pool?.release(key, this);
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
