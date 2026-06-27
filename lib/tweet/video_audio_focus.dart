import 'package:audio_session/audio_session.dart';
import 'package:media_kit/media_kit.dart';

/// Wires media_kit [Player]s to an [AudioSession]: libmpv's Android audio
/// output doesn't integrate with system audio focus on its own, so a video
/// would otherwise play over other apps and through phone calls.
class VideoAudioFocus {
  VideoAudioFocus._();
  static final VideoAudioFocus instance = VideoAudioFocus._();

  AudioSession? _session;
  bool _initStarted = false;
  Player? _active;
  bool _resumeAfterInterruption = false;

  Future<void> _ensureInit() async {
    if (_initStarted) return;
    _initStarted = true;

    final session = await AudioSession.instance;
    _session = session;
    await session.configure(const AudioSessionConfiguration(
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.movie,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: false,
    ));

    session.interruptionEventStream.listen(_onInterruption);
    session.becomingNoisyEventStream.listen((_) => _active?.pause());
  }

  void _onInterruption(AudioInterruptionEvent event) {
    final player = _active;
    if (player == null) return;
    // A transient "duck" (e.g. a notification chime) shouldn't pause a video —
    // only real interruptions (a call, another media app taking focus) do.
    if (event.type == AudioInterruptionType.duck) return;
    if (event.begin) {
      _resumeAfterInterruption = player.state.playing;
      player.pause();
    } else if (_resumeAfterInterruption) {
      _resumeAfterInterruption = false;
      player.play();
    }
  }

  Future<void> onStartedPlaying(Player player, {required bool mixWithOthers}) async {
    _active = player;
    if (mixWithOthers) return;
    await _ensureInit();
    await _session?.setActive(true);
  }

  Future<void> onStoppedPlaying(Player player) async {
    if (!identical(_active, player)) return;
    _active = null;
    await _session?.setActive(false);
  }
}
