import 'package:better_player_plus/better_player_plus.dart'
    hide VisibilityDetector, VisibilityDetectorController, VisibilityInfo;
import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/space/space.dart';
import 'package:quax/space/space_model.dart';
import 'package:quax/space/space_playback.dart';
import 'package:quax/space/space_status.dart';
import 'package:quax/ui/errors.dart';

class SpacePlayer extends StatelessWidget {
  final Space space;
  final bool autoplay;

  const SpacePlayer({super.key, required this.space, required this.autoplay});

  @override
  Widget build(BuildContext context) {
    final live = space.state == SpaceState.live;
    return Provider(
      create: (_) => SpaceStreamModel(space.mediaKey!)..load(),
      dispose: (_, SpaceStreamModel model) => model.destroy(),
      child: Builder(
        builder: (context) {
          final model = context.read<SpaceStreamModel>();
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: ScopedBuilder<SpaceStreamModel, String>(
              store: model,
              onLoading: (_) => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
              onError: (context, error) => _PlaybackError(error: error, onRetry: model.load),
              onState: (_, playlist) => _SpaceAudio(playlist: playlist, live: live, autoplay: autoplay),
            ),
          );
        },
      ),
    );
  }
}

class _PlaybackError extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _PlaybackError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) =>
      ErrorCard(error: error, stackTrace: null, prefix: (l10n) => l10n.unable_to_play_the_space, onRetry: onRetry);
}

class _SpaceAudio extends StatefulWidget {
  final String playlist;
  final bool live;
  final bool autoplay;

  const _SpaceAudio({required this.playlist, required this.live, required this.autoplay});

  @override
  State<_SpaceAudio> createState() => _SpaceAudioState();
}

class _SpaceAudioState extends State<_SpaceAudio> {
  late final BetterPlayerController _controller = BetterPlayerController(
    BetterPlayerConfiguration(
      autoPlay: widget.autoplay,
      // Keeps playing when the app goes to the background, like any audio app
      handleLifecycle: false,
      controlsConfiguration: const BetterPlayerControlsConfiguration(showControls: false),
    ),
    betterPlayerDataSource: BetterPlayerDataSource.network(
      widget.playlist,
      liveStream: widget.live,
      videoFormat: BetterPlayerVideoFormat.hls,
      headers: const {'Referer': 'https://x.com/'},
    ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _controller.videoPlayerController!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // An audio stream draws nothing, but the player needs to be in the tree
        SizedBox.square(dimension: 1, child: BetterPlayer(controller: _controller)),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: video,
          builder: (context, value, _) => value.hasError
              ? _PlaybackError(error: value.errorDescription, onRetry: () => _controller.retryDataSource())
              : _Controls(controller: _controller, value: value, live: widget.live),
        ),
      ],
    );
  }
}

class _Controls extends StatelessWidget {
  final BetterPlayerController controller;
  final VideoPlayerValue value;
  final bool live;

  const _Controls({required this.controller, required this.value, required this.live});

  void _skipBy(Duration offset) =>
      controller.seekTo(skipTarget(value.position, offset, value.duration ?? Duration.zero));

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final play = _PlayButton(controller: controller, value: value);
    if (live) return Center(child: play);
    final duration = value.duration ?? Duration.zero;
    final ready = value.initialized;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProgressBar(controller: controller, value: value),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SpeedButton(controller: controller, speed: value.speed, enabled: ready),
            IconButton(
              icon: Icon(Icons.replay_10, semanticLabel: l10n.space_back_10_seconds),
              onPressed: ready ? () => _skipBy(-skipStep) : null,
            ),
            play,
            IconButton(
              icon: Icon(Icons.forward_10, semanticLabel: l10n.space_forward_10_seconds),
              onPressed: ready ? () => _skipBy(skipStep) : null,
            ),
            _TimeLabel('-${formatSpaceDuration(timeLeft(value.position, duration))}'),
          ],
        ),
      ],
    );
  }
}

/// A time beside the controls, as wide as the speed button so the play button stays centred.
class _TimeLabel extends StatelessWidget {
  final String text;

  const _TimeLabel(this.text);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: _sideSlotWidth,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelMedium!.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

const _sideSlotWidth = 56.0;

class _ProgressBar extends StatelessWidget {
  final BetterPlayerController controller;
  final VideoPlayerValue value;

  const _ProgressBar({required this.controller, required this.value});

  @override
  Widget build(BuildContext context) {
    final duration = value.duration ?? Duration.zero;
    final max = duration.inMilliseconds.toDouble();
    return Row(
      children: [
        _TimeLabel(formatSpaceDuration(value.position)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(padding: EdgeInsets.zero, trackHeight: 4),
            child: Slider(
              value: value.position.inMilliseconds.clamp(0, max).toDouble(),
              max: max <= 0 ? 1 : max,
              onChanged: max <= 0 ? null : (millis) => controller.seekTo(Duration(milliseconds: millis.round())),
            ),
          ),
        ),
        _TimeLabel(formatSpaceDuration(duration)),
      ],
    );
  }
}

class _PlayButton extends StatelessWidget {
  final BetterPlayerController controller;
  final VideoPlayerValue value;

  const _PlayButton({required this.controller, required this.value});

  @override
  Widget build(BuildContext context) {
    final loading = !value.initialized || (value.isBuffering && !value.isPlaying);
    final colors = Theme.of(context).colorScheme;
    return IconButton.filled(
      iconSize: 36,
      padding: const EdgeInsets.all(12),
      style: IconButton.styleFrom(
        // The same tint as while it loads, so the button keeps its color once the space plays
        backgroundColor: colors.onSurface.withValues(alpha: 0.12),
        foregroundColor: colors.primary,
      ),
      onPressed: loading ? null : () => value.isPlaying ? controller.pause() : controller.play(),
      icon: AnimatedSwitcher(
        duration: _playPauseMorph,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween(begin: 0.6, end: 1.0).animate(animation), child: child),
        ),
        child: loading
            ? const SizedBox.square(
                key: ValueKey('loading'),
                dimension: 36,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            : TweenAnimationBuilder<double>(
                key: const ValueKey('ready'),
                tween: Tween(end: value.isPlaying ? 1 : 0),
                duration: _playPauseMorph,
                curve: Curves.easeInOut,
                builder: (context, playing, _) => AnimatedIcon(
                  icon: AnimatedIcons.play_pause,
                  progress: AlwaysStoppedAnimation(playing),
                  semanticLabel: value.isPlaying ? L10n.of(context).pause : L10n.of(context).play,
                ),
              ),
      ),
    );
  }
}

const _playPauseMorph = Duration(milliseconds: 300);

class _SpeedButton extends StatelessWidget {
  final BetterPlayerController controller;
  final double speed;
  final bool enabled;

  const _SpeedButton({required this.controller, required this.speed, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: L10n.of(context).playback_speed,
      child: SizedBox(
        width: _sideSlotWidth,
        child: TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: enabled ? () => controller.setSpeed(nextPlaybackSpeed(speed)) : null,
          child: Text('${speed.toString().replaceAll(RegExp(r'\.0$'), '')}×'),
        ),
      ),
    );
  }
}
