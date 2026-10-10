import 'dart:ui' show Size;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:better_player_plus/src/video_player/video_player.dart' show VideoPlayerController;

/// A player that never touches the platform: play and pause only flip the
/// playback value and post the event the real controller would.
class FakeVideoController extends BetterPlayerController {
  int pauseCalls = 0;
  int playCalls = 0;
  final List<Duration> seeks = [];

  FakeVideoController({bool isPlaying = false, bool isBuffering = false})
    : super(const BetterPlayerConfiguration(autoDispose: false)) {
    videoPlayerController = VideoPlayerController(autoCreate: false)
      ..value = VideoPlayerValue(
        duration: const Duration(minutes: 1),
        isPlaying: isPlaying,
        isBuffering: isBuffering,
        size: const Size(100, 100),
      );
  }

  /// Changes the playback state and tells the listeners, like the player does.
  void emit({bool? isPlaying, bool? isBuffering}) {
    final player = videoPlayerController!;
    player.value = player.value.copyWith(isPlaying: isPlaying, isBuffering: isBuffering);
    postEvent(BetterPlayerEvent(BetterPlayerEventType.progress));
  }

  @override
  Future<void> play() async {
    playCalls++;
    emit(isPlaying: true);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    emit(isPlaying: false);
  }

  @override
  Future<void> seekTo(Duration moment) async => seeks.add(moment);

  @override
  Future<void> setVolume(double volume) async {}

  @override
  void dispose({bool forceDispose = false}) {
    if (forceDispose) videoPlayerController = null;
  }
}
