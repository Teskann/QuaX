import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/_video_controls.dart';
import 'package:quax/tweet/video_controller_pool.dart';
import 'package:quax/utils/downloads.dart';
import 'package:quax/utils/iterables.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class TweetVideoUrls {
  final String streamUrl;
  final String? downloadUrl;

  TweetVideoUrls(this.streamUrl, this.downloadUrl);
}

class TweetVideoMetadata {
  final double aspectRatio;
  final String? imageUrl;
  final Future<TweetVideoUrls> Function() streamUrlsBuilder;

  TweetVideoMetadata(this.aspectRatio, this.imageUrl, this.streamUrlsBuilder);

  static Future<TweetVideoUrls> Function() streamUrlsBuilderFromVariants(List<Variant> variants) {
    var streamUrl = variants[0].url!;
    var downloadUrl = variants
        .where((e) => e.bitrate != null)
        .where((e) => e.url != null)
        .where((e) => e.contentType == 'video/mp4')
        .sorted((a, b) => -(a.bitrate!.compareTo(b.bitrate!)))
        .map((e) => e.url)
        .firstWhereOrNull((e) => e != null);

    return () async => TweetVideoUrls(streamUrl, downloadUrl);
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

  bool? _autoPlay;
  bool _userRequestedPlay = false;
  final Key _visibilityKey = UniqueKey();
  Timer? _pauseTimer;
  VoidCallback? _muteListener;

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

  Future<PooledVideo> _createPooled(
      bool prefLoop, bool prefAutoPlay, bool prefBackgroundPlayback, bool prefMixWithOthers, bool startMuted) async {
    var urls = await widget.metadata.streamUrlsBuilder();
    var downloadUrl = urls.downloadUrl;

    var videoController = VideoPlayerController.networkUrl(Uri.parse(urls.streamUrl),
        videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: widget.disableControls || prefMixWithOthers, allowBackgroundPlayback: prefBackgroundPlayback));

    videoController.setVolume(startMuted ? 0.0 : videoController.value.volume);

    late ChewieController chewieController;
    chewieController = ChewieController(
      aspectRatio: widget.metadata.aspectRatio,
      autoInitialize: true,
      autoPlay: widget.alwaysPlay || _userRequestedPlay,
      placeholder: widget.metadata.imageUrl != null
          ? Image.network(widget.metadata.imageUrl!, fit: BoxFit.cover)
          : null,
      allowMuting: !widget.disableControls,
      showControls: !widget.disableControls,
      allowedScreenSleep: false,
      customControls: const FritterMaterialControls(),
      additionalOptions: (context) => [
        OptionItem(
          onTap: (BuildContext optionContext) async {
            var video = downloadUrl;
            if (video == null) {
              ScaffoldMessenger.of(optionContext).showSnackBar(SnackBar(
                content: Text(L10n.current.download_media_no_url),
              ));
              return;
            }

            var videoUri = Uri.parse(video);
            var fileName = '${widget.username}-${path.basename(videoUri.path)}';

            await downloadUriToPickedFile(
              optionContext,
              videoUri,
              fileName,
              prefs: PrefService.of(optionContext),
              onStart: () {
                ScaffoldMessenger.of(optionContext).showSnackBar(SnackBar(
                  content: Text(L10n.of(optionContext).downloading_media),
                ));
              },
              onSuccess: () {
                ScaffoldMessenger.of(optionContext).showSnackBar(SnackBar(
                  content: Text(L10n.of(optionContext).successfully_saved_the_media),
                ));
              },
            );
          },
          iconData: Icons.download,
          title: L10n.of(context).download,
        )
      ],
      looping: widget.loop || prefLoop,
      videoPlayerController: videoController,
    );

    videoController.addListener(() {
      if (chewieController.isPlaying) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });

    return PooledVideo(
      videoController: videoController,
      chewieController: chewieController,
      downloadUrl: downloadUrl,
    );
  }

  Future<PooledVideo> _acquire(
      bool prefLoop, bool prefAutoPlay, bool prefBackgroundPlayback, bool prefMixWithOthers) async {
    var startMuted = context.read<VideoContextState>().isMuted;
    create() => _createPooled(prefLoop, prefAutoPlay, prefBackgroundPlayback, prefMixWithOthers, startMuted);

    final key = _cacheKey;
    final pool = _pool;
    PooledVideo pooled;
    if (key == null || pool == null) {
      _ownsControllers = true;
      pooled = await create();
      if (!mounted) {
        pooled.dispose();
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
    _attachMuteSync(pooled);
    return pooled;
  }

  void _attachMuteSync(PooledVideo pooled) {
    var model = context.read<VideoContextState>();
    // Reflect the current screen's mute state onto the (possibly reused) video.
    pooled.videoController.setVolume(model.isMuted ? 0.0 : pooled.videoController.value.volume);
    listener() => model.setIsMuted(pooled.videoController.value.volume);
    pooled.videoController.addListener(listener);
    _muteListener = listener;
  }

  void _detachMuteSync() {
    if (_muteListener != null) {
      _pooled?.videoController.removeListener(_muteListener!);
      _muteListener = null;
    }
  }

  void _onVisibilityChanged(VisibilityInfo info, PooledVideo pooled) {
    if (!mounted) return;
    final key = _cacheKey;
    if (info.visibleFraction >= 0.75) {
      if (key != null) _pool?.markVisible(key, this);
      _pauseTimer?.cancel();
      _pauseTimer = null;
      if (_autoPlay! && !pooled.chewieController.isPlaying) {
        pooled.chewieController.play();
      }
    } else if (!widget.alwaysPlay && info.visibleFraction <= 0.5) {
      if (key != null) _pool?.markHidden(key, this);
      _pauseTimer ??= Timer(const Duration(milliseconds: 100), () {
        _pauseTimer = null;
        if (key != null && (_pool?.anyVisible(key) ?? false)) return;
        if (mounted && !pooled.chewieController.isFullScreen) {
          pooled.chewieController.pause();
        }
      });
    }
  }

  Future<void> _restartVideo(bool prefLoop, prefAutoPlay, prefBackgroundPlayback, prefMixWithOthers) async {
    _detachMuteSync();
    final key = _cacheKey;
    if (key != null && _pool != null) {
      if (_holdsPoolRef) {
        _pool!.release(key);
        _holdsPoolRef = false;
      }
      _pool!.invalidate(key);
    } else {
      await _pooled?.videoController.pause();
      _pooled?.dispose();
    }

    setState(() {
      _pooled = null;
      _acquireFuture = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context);
    final prefLoop = prefs.get(optionMediaDefaultLoop);
    final prefAutoPlay = prefs.get(optionMediaDefaultAutoPlay);
    final prefBackgroundPlayback = prefs.get(optionMediaBackgroundPlayback);
    final prefMixWithOthers = prefs.get(optionMediaAllowBackgroundPlayOtherApps);

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
    _acquireFuture ??= _acquire(prefLoop, prefAutoPlay, prefBackgroundPlayback, prefMixWithOthers);

    return FutureBuilder(
      future: _acquireFuture,
      builder: (context, snapshot) {
        final hasError = snapshot.hasError;
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

        if (hasError && !hasVideo) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text('Failed to load video'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => _restartVideo(prefLoop, prefAutoPlay, prefBackgroundPlayback, prefMixWithOthers),
                  child: const Text('Restart Video Player'),
                ),
              ],
            ),
          );
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: widget.metadata.aspectRatio,
              child: hasVideo
                  ? VisibilityDetector(
                      key: _visibilityKey,
                      onVisibilityChanged: (info) => _onVisibilityChanged(info, pooled),
                      child: Chewie(
                        controller: pooled.chewieController,
                      ))
                  : const SizedBox.shrink(),
            ),
            if (hasError)
              Positioned(
                right: 8,
                bottom: 8,
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: () => _restartVideo(prefLoop, prefAutoPlay, prefBackgroundPlayback, prefMixWithOthers),
                  tooltip: 'Restart player',
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    if (_pooled?.chewieController.isFullScreen ?? false) {
      super.dispose();
      return;
    }
    _detachMuteSync();
    final key = _cacheKey;
    if (key != null) _pool?.markHidden(key, this);
    if (_ownsControllers) {
      _pooled?.dispose();
    } else if (key != null && _holdsPoolRef) {
      _pool?.release(key);
      _holdsPoolRef = false;
    }
    WakelockPlus.disable();
    super.dispose();
  }
}

class VideoContextState extends ChangeNotifier {
  static bool? _muted;

  VideoContextState(bool initialMuted) {
    _muted ??= initialMuted;
  }

  bool get isMuted => _muted!;

  void setIsMuted(double volume) {
    final muted = _muted!;
    if (muted && volume > 0 || !muted && volume == 0) {
      _muted = !muted;
    }

    notifyListeners();
  }
}
