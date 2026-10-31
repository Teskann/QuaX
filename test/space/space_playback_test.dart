import 'package:flutter_test/flutter_test.dart';
import 'package:quax/space/space_playback.dart';

void main() {
  group('nextPlaybackSpeed()', () {
    test('Should go through the speeds, then back to the first', () {
      expect(nextPlaybackSpeed(1), 1.25, reason: 'Each tap on the speed button moves to the next speed');
      expect(nextPlaybackSpeed(2), 1, reason: 'After the fastest speed comes the normal one again');
    });

    test('Should start over from a speed it does not offer', () {
      expect(
        nextPlaybackSpeed(0.5),
        playbackSpeeds.first,
        reason: 'A speed set elsewhere should not leave the button stuck',
      );
    });
  });

  group('skipTarget()', () {
    const length = Duration(minutes: 10);

    test('Should move by the offset inside the recording', () {
      expect(
        skipTarget(const Duration(minutes: 5), skipStep, length),
        const Duration(minutes: 5, seconds: 10),
        reason: 'Forward 10 seconds',
      );
      expect(
        skipTarget(const Duration(minutes: 5), -skipStep, length),
        const Duration(minutes: 4, seconds: 50),
        reason: 'Back 10 seconds',
      );
    });

    test('Should stop at both ends of the recording', () {
      expect(
        skipTarget(const Duration(seconds: 3), -skipStep, length),
        Duration.zero,
        reason: 'Going back from the first seconds lands on the start',
      );
      expect(
        skipTarget(length - const Duration(seconds: 3), skipStep, length),
        length,
        reason: 'Going forward from the last seconds lands on the end',
      );
    });
  });

  group('timeLeft()', () {
    test('Should never go below zero', () {
      expect(
        timeLeft(const Duration(minutes: 4), const Duration(minutes: 10)),
        const Duration(minutes: 6),
        reason: 'What remains of the recording',
      );
      expect(
        timeLeft(const Duration(minutes: 3), Duration.zero),
        Duration.zero,
        reason: 'Before the player knows the length, the time left would read negative',
      );
    });
  });
}
