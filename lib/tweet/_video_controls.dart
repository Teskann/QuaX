import 'dart:async';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;
import 'package:pref/pref.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/video_controller_pool.dart';
import 'package:quax/tweet/video_quality.dart';
import 'package:quax/utils/downloads.dart';

Player _playerOf(BuildContext context) =>
    VideoStateInheritedWidget.of(context).state.widget.controller.player;

const _kSeekSeconds = 10;

class QuaxControls extends StatefulWidget {
  final PooledVideo pooled;
  final String username;
  final bool allowMuting;
  final Color accentColor;
  final bool subtitlesEnabled;
  final VoidCallback onToggleSubtitles;

  const QuaxControls({
    super.key,
    required this.pooled,
    required this.username,
    required this.allowMuting,
    required this.accentColor,
    required this.subtitlesEnabled,
    required this.onToggleSubtitles,
  });

  @override
  State<QuaxControls> createState() => _QuaxControlsState();
}

class _QuaxControlsState extends State<QuaxControls> {
  bool _visible = true;
  Timer? _hideTimer;

  double _lastTapX = 0;
  int _seekFeedback = 0;
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _toggle() {
    setState(() => _visible = !_visible);
    if (_visible) {
      _scheduleHide();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _onDoubleTap() {
    final width = context.size?.width ?? 0;
    final player = _playerOf(context);
    final back = _lastTapX < width / 2;
    final delta = Duration(seconds: back ? -_kSeekSeconds : _kSeekSeconds);
    var target = player.state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > player.state.duration) target = player.state.duration;
    player.seek(target);

    setState(() => _seekFeedback = back ? -_kSeekSeconds : _kSeekSeconds);
    _feedbackTimer?.cancel();
    _feedbackTimer = Timer(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _seekFeedback = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const theme = MaterialVideoControlsThemeData(
      buttonBarButtonColor: Colors.white,
    );

    return MaterialVideoControlsTheme(
      normal: theme,
      fullscreen: theme,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              onDoubleTapDown: (d) => _lastTapX = d.localPosition.dx,
              onDoubleTap: _onDoubleTap,
              child: AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  children: [
                    // IgnorePointer so the opaque scrim never swallows taps,
                    // which would make the controls impossible to dismiss.
                    const Positioned.fill(
                      child: IgnorePointer(child: ColoredBox(color: Colors.black45)),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: !_visible,
                        child: Listener(
                          onPointerDown: (_) {
                            if (_visible) _scheduleHide();
                          },
                          child: _controls(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_seekFeedback != 0)
            Positioned.fill(
              child: IgnorePointer(
                child: Align(
                  alignment: _seekFeedback < 0 ? Alignment.centerLeft : Alignment.centerRight,
                  child: _seekFeedbackBadge(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Stack(
      children: [
        const Center(child: _PlayPauseButton()),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _BottomBar(
            pooled: widget.pooled,
            username: widget.username,
            allowMuting: widget.allowMuting,
            accentColor: widget.accentColor,
            subtitlesEnabled: widget.subtitlesEnabled,
            onToggleSubtitles: widget.onToggleSubtitles,
          ),
        ),
      ],
    );
  }

  Widget _seekFeedbackBadge() {
    final back = _seekFeedback < 0;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(back ? Icons.fast_rewind : Icons.fast_forward, color: Colors.white),
          const SizedBox(height: 4),
          Text('$_kSeekSeconds s', style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final PooledVideo pooled;
  final String username;
  final bool allowMuting;
  final Color accentColor;
  final bool subtitlesEnabled;
  final VoidCallback onToggleSubtitles;

  const _BottomBar({
    required this.pooled,
    required this.username,
    required this.allowMuting,
    required this.accentColor,
    required this.subtitlesEnabled,
    required this.onToggleSubtitles,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 14, right: 4),
          child: Row(
            children: [
              const _PositionIndicator(),
              const Spacer(),
              if (allowMuting) const _MuteButton(),
              _MoreButton(
                pooled: pooled,
                username: username,
                subtitlesEnabled: subtitlesEnabled,
                onToggleSubtitles: onToggleSubtitles,
              ),
              const MaterialFullscreenButton(),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -8),
          child: Padding(
            padding: const EdgeInsets.only(left: 14, right: 16, bottom: 6),
            child: _SeekBar(accentColor: accentColor),
          ),
        ),
      ],
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  const _PlayPauseButton();

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton> {
  final List<StreamSubscription> _subs = [];
  bool _playing = false;
  bool _completed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subs.isNotEmpty) return;
    final player = _playerOf(context);
    _playing = player.state.playing;
    _completed = player.state.completed;
    _subs.add(player.stream.playing.listen((v) {
      if (mounted) setState(() => _playing = v);
    }));
    _subs.add(player.stream.completed.listen((v) {
      if (mounted) setState(() => _completed = v);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  void _onTap() {
    final player = _playerOf(context);
    final wasCompleted = _completed;
    // Flip the icon immediately so the button feels instant; the streams
    // confirm/correct it after libmpv's play/pause latency.
    setState(() {
      _completed = false;
      _playing = wasCompleted ? true : !_playing;
    });
    if (wasCompleted) {
      // libmpv leaves the position at EOF, so play() alone wouldn't replay.
      player.seek(Duration.zero);
      player.play();
    } else {
      player.playOrPause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
        child: Center(
          child: _completed
              ? const Icon(Icons.replay, color: Colors.white, size: 32)
              : AnimatedPlayPause(playing: _playing, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class AnimatedPlayPause extends StatefulWidget {
  final bool playing;
  final double? size;
  final Color? color;

  const AnimatedPlayPause({super.key, required this.playing, this.size, this.color});

  @override
  State<AnimatedPlayPause> createState() => _AnimatedPlayPauseState();
}

class _AnimatedPlayPauseState extends State<AnimatedPlayPause>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.playing ? 1 : 0,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void didUpdateWidget(AnimatedPlayPause oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing != oldWidget.playing) {
      widget.playing ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedIcon(
      icon: AnimatedIcons.play_pause,
      progress: _controller,
      size: widget.size,
      color: widget.color,
    );
  }
}

class _PositionIndicator extends StatefulWidget {
  const _PositionIndicator();

  @override
  State<_PositionIndicator> createState() => _PositionIndicatorState();
}

class _PositionIndicatorState extends State<_PositionIndicator> {
  final List<StreamSubscription> _subs = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subs.isNotEmpty) return;
    final player = _playerOf(context);
    _position = player.state.position;
    _duration = player.state.duration;
    _subs.add(player.stream.position.listen((v) {
      if (mounted) setState(() => _position = v);
    }));
    _subs.add(player.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = h > 0 ? m.toString().padLeft(2, '0') : m.toString();
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: '${_fmt(_position)} ',
        style: const TextStyle(fontSize: 14.0, color: Colors.white, fontWeight: FontWeight.bold),
        children: [
          TextSpan(
            text: '/ ${_fmt(_duration)}',
            style: TextStyle(
              fontSize: 14.0,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom because media_kit's [MaterialSeekBar] draws square-cornered bars.
class _SeekBar extends StatefulWidget {
  final Color accentColor;

  const _SeekBar({required this.accentColor});

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  final List<StreamSubscription> _subs = [];
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  double? _dragFraction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_subs.isNotEmpty) return;
    final player = _playerOf(context);
    _position = player.state.position;
    _duration = player.state.duration;
    _buffer = player.state.buffer;
    _subs.add(player.stream.position.listen((v) {
      if (mounted && _dragFraction == null) setState(() => _position = v);
    }));
    _subs.add(player.stream.duration.listen((v) {
      if (mounted) setState(() => _duration = v);
    }));
    _subs.add(player.stream.buffer.listen((v) {
      if (mounted) setState(() => _buffer = v);
    }));
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  double _fraction(Duration d) {
    final total = _duration.inMilliseconds;
    return total == 0 ? 0.0 : (d.inMilliseconds / total).clamp(0.0, 1.0);
  }

  double get _playedFraction => _dragFraction ?? _fraction(_position);

  void _commitSeek() {
    final f = _dragFraction;
    if (f != null) {
      _playerOf(context).seek(_duration * f);
    }
    setState(() => _dragFraction = null);
  }

  @override
  Widget build(BuildContext context) {
    const trackHeight = 10.0;
    const thumbSize = 12.0;
    final trackColor = Theme.of(context).disabledColor.withValues(alpha: 0.5);
    final bufferColor = Theme.of(context).colorScheme.surface.withValues(alpha: 0.5);
    final radius = BorderRadius.circular(trackHeight / 2);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final played = _playedFraction;
        final buffered = _fraction(_buffer);

        void update(double dx) {
          setState(() => _dragFraction = (dx / width).clamp(0.0, 1.0));
        }

        // Explicit width + left anchor so the fill grows from the left edge; an
        // unpositioned child in this centered Stack would grow from the middle.
        Widget bar(double w, Color color) => Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: w,
                height: trackHeight,
                decoration: BoxDecoration(color: color, borderRadius: radius),
              ),
            );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => update(d.localPosition.dx),
          onTapUp: (_) => _commitSeek(),
          onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
          onHorizontalDragEnd: (_) => _commitSeek(),
          child: SizedBox(
            width: width,
            height: thumbSize + 12,
            child: Stack(
              alignment: Alignment.center,
              // Clip.none lets the thumb overflow into the padding at the ends,
              // so near 0 it isn't pinned and left lagging behind the played bar.
              clipBehavior: Clip.none,
              children: [
                bar(width, trackColor),
                bar(width * buffered, bufferColor),
                bar(width * played, widget.accentColor),
                Positioned(
                  left: width * played - thumbSize / 2,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: thumbSize,
                      height: thumbSize,
                      decoration: BoxDecoration(color: widget.accentColor, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MuteButton extends StatefulWidget {
  const _MuteButton();

  @override
  State<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<_MuteButton> {
  StreamSubscription<double>? _sub;
  double _volume = 100.0;
  double _lastNonZero = 100.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final player = _playerOf(context);
    _volume = player.state.volume;
    if (_volume > 0) _lastNonZero = _volume;
    _sub ??= player.stream.volume.listen((v) {
      if (!mounted) return;
      setState(() {
        _volume = v;
        if (v > 0) _lastNonZero = v;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 24.0,
      color: Colors.white,
      icon: Icon(_volume > 0 ? Icons.volume_up : Icons.volume_off),
      onPressed: () => _playerOf(context)
          .setVolume(_volume > 0 ? 0.0 : (_lastNonZero > 0 ? _lastNonZero : 100.0)),
    );
  }
}

class _MoreButton extends StatelessWidget {
  final PooledVideo pooled;
  final String username;
  final bool subtitlesEnabled;
  final VoidCallback onToggleSubtitles;

  const _MoreButton({
    required this.pooled,
    required this.username,
    required this.subtitlesEnabled,
    required this.onToggleSubtitles,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: 24.0,
      color: Colors.white,
      icon: const Icon(Icons.more_vert),
      onPressed: () => _openMenu(context),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final player = _playerOf(context);
    // Only offer the subtitle toggle if the video carries a subtitle track.
    final hasSubtitles =
        player.state.tracks.subtitle.any((t) => t.id != 'no' && t.id != 'auto');
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.speed),
              title: Text(L10n.of(sheetContext).playback_speed),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openSpeedSheet(context, player);
              },
            ),
            if (pooled.qualities.length > 1)
              ListTile(
                leading: const Icon(Icons.high_quality),
                title: Text(L10n.of(sheetContext).quality),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openQualitySheet(context, pooled);
                },
              ),
            if (hasSubtitles)
              ListTile(
                leading: Icon(subtitlesEnabled ? Icons.closed_caption : Icons.closed_caption_off),
                title: Text(L10n.of(sheetContext).subtitles),
                trailing: subtitlesEnabled ? const Icon(Icons.check) : null,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onToggleSubtitles();
                },
              ),
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(L10n.of(sheetContext).download),
              onTap: () {
                Navigator.of(sheetContext).pop();
                downloadTweetVideo(context, username, pooled.downloadUrl);
              },
            ),
          ],
        ),
      ),
    );
  }
}

const _kSpeeds = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

Future<void> _openSpeedSheet(BuildContext context, Player player) async {
  final chosen = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _SpeedSheet(speeds: _kSpeeds, selected: player.state.rate),
  );
  if (chosen != null) {
    await player.setRate(chosen);
  }
}

Future<void> _openQualitySheet(BuildContext context, PooledVideo pooled) async {
  final chosen = await showModalBottomSheet<TweetVideoQuality>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => _QualitySheet(
      qualities: pooled.qualities,
      selectedUrl: pooled.currentStreamUrl,
    ),
  );
  if (chosen == null || chosen.url == pooled.currentStreamUrl) {
    return;
  }

  final player = pooled.player;
  final wasPlaying = player.state.playing;
  final volume = player.state.volume;
  final rate = player.state.rate;

  // The new variant restarts from 0: preserving position across the source swap
  // proved unreliable on libmpv's Android network playback.
  pooled.currentStreamUrl = chosen.url;
  await player.open(Media(chosen.url), play: wasPlaying);
  await player.setVolume(volume);
  await player.setRate(rate);
}

Future<void> downloadTweetVideo(BuildContext context, String username, String? downloadUrl) async {
  if (downloadUrl == null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L10n.current.download_media_no_url),
    ));
    return;
  }

  final videoUri = Uri.parse(downloadUrl);
  final fileName = '$username-${path.basename(videoUri.path)}';

  await downloadUriToPickedFile(
    context,
    videoUri,
    fileName,
    prefs: PrefService.of(context),
    onStart: () {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.of(context).downloading_media),
      ));
    },
    onSuccess: () {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n.of(context).successfully_saved_the_media),
      ));
    },
  );
}

class _SpeedSheet extends StatelessWidget {
  final List<double> speeds;
  final double selected;

  const _SpeedSheet({required this.speeds, required this.selected});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: speeds.reversed.map((speed) {
          final isSelected = (speed - selected).abs() < 0.01;
          return ListTile(
            leading: isSelected ? const Icon(Icons.check) : const SizedBox(width: 24),
            title: Text('${speed}x'),
            onTap: () => Navigator.of(context).pop(speed),
          );
        }).toList(),
      ),
    );
  }
}

class _QualitySheet extends StatelessWidget {
  final List<TweetVideoQuality> qualities;
  final String selectedUrl;

  const _QualitySheet({required this.qualities, required this.selectedUrl});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: qualities.map((quality) {
          final isSelected = quality.url == selectedUrl;
          return ListTile(
            leading: isSelected ? const Icon(Icons.check) : const SizedBox(width: 24),
            title: Text(quality.label),
            onTap: () => Navigator.of(context).pop(quality),
          );
        }).toList(),
      ),
    );
  }
}

class FritterCenterPlayButton extends StatelessWidget {
  const FritterCenterPlayButton({
    super.key,
    required this.backgroundColor,
    this.iconColor,
    required this.show,
    required this.isPlaying,
    required this.isFinished,
    this.onPressed,
    this.size = 64.0,
  });

  final Color backgroundColor;
  final Color? iconColor;
  final bool show;
  final bool isPlaying;
  final bool isFinished;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Center(
        child: AnimatedOpacity(
          opacity: show ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: GestureDetector(
            onTap: onPressed,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                iconSize: size / 2,
                icon: isFinished
                    ? Icon(Icons.replay, color: iconColor)
                    : AnimatedPlayPause(playing: isPlaying, color: iconColor, size: size / 2),
                onPressed: onPressed,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
