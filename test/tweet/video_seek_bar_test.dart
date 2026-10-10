import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/_video_controls.dart';

import '../ui/pump_app.dart';
import 'fake_video_controller.dart';

void main() {
  late FakeVideoController controller;

  // Builds the frame a change asks for, then lets the animations it starts end.
  Future<void> settleFrames(WidgetTester tester, [Duration elapsed = const Duration(seconds: 1)]) async {
    await tester.pump();
    await tester.pump(elapsed);
  }

  // The controls hide themselves a few seconds after they were shown.
  Future<void> hideControls(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await settleFrames(tester);
  }

  Future<void> pumpControls(WidgetTester tester, FakeVideoController fake) async {
    controller = fake;
    await pumpInApp(
      tester,
      QuaxControls(controller: fake, username: 'quax', qualities: const [], downloadUrl: null),
      settle: false,
    );
    await settleFrames(tester);
  }

  Finder seekBar() => find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SeekBar');

  int scheduledFrames() => SchedulerBinding.instance.transientCallbackCount;

  group('Seek bar ticker', () {
    testWidgets('Should not schedule frames while the video is paused', (tester) async {
      await pumpControls(tester, FakeVideoController());

      expect(
        scheduledFrames(),
        0,
        reason:
            'A paused video has nothing to animate: a running ticker would wake the device up '
            'on every vsync for every player in the feed',
      );
    });

    testWidgets('Should schedule frames while the video plays with the controls shown', (tester) async {
      await pumpControls(tester, FakeVideoController(isPlaying: true));

      expect(scheduledFrames(), 1, reason: 'The played bar has to advance smoothly while the video plays');
    });

    testWidgets('Should stop scheduling frames once the controls hide', (tester) async {
      await pumpControls(tester, FakeVideoController(isPlaying: true));

      await hideControls(tester);

      expect(scheduledFrames(), 0, reason: 'A bar nobody can see must not keep the device awake');
    });

    testWidgets('Should schedule frames again when the controls come back', (tester) async {
      await pumpControls(tester, FakeVideoController(isPlaying: true));
      await hideControls(tester);

      await tester.tapAt(const Offset(10, 10));
      // A tap waits to rule out a double tap before it counts.
      await tester.pump(const Duration(milliseconds: 400));
      await settleFrames(tester);

      expect(scheduledFrames(), 1, reason: 'The bar has to catch up with the video once it is shown again');
    });

    testWidgets('Should stop scheduling frames when the video pauses', (tester) async {
      await pumpControls(tester, FakeVideoController(isPlaying: true));

      await controller.pause();
      await settleFrames(tester);

      expect(scheduledFrames(), 0, reason: 'Pausing a video must stop the bar from animating');
    });

    testWidgets('Should stop scheduling frames while the video buffers', (tester) async {
      await pumpControls(tester, FakeVideoController(isPlaying: true));

      controller.emit(isBuffering: true);
      await settleFrames(tester);

      expect(
        scheduledFrames(),
        1,
        reason: 'Only the buffering spinner animates: the bar is frozen while buffering, so it must not tick too',
      );
    });

    testWidgets('Should start scheduling frames when a paused video plays', (tester) async {
      await pumpControls(tester, FakeVideoController());

      await controller.play();
      await settleFrames(tester);

      expect(scheduledFrames(), 1, reason: 'Playing has to start the bar moving again');
    });

    testWidgets('Should stop scheduling frames while the user drags the bar', (tester) async {
      await pumpControls(tester, FakeVideoController(isPlaying: true));

      final gesture = await tester.startGesture(tester.getCenter(seekBar()));
      await tester.pump(const Duration(milliseconds: 200));

      expect(scheduledFrames(), 0, reason: 'While dragging, the bar follows the finger, not the video');

      await gesture.up();
      await settleFrames(tester);

      expect(controller.seeks, hasLength(1), reason: 'Releasing the bar has to seek to where it was dropped');
      expect(scheduledFrames(), 1, reason: 'Once the user lets go, the bar has to follow the video again');
    });
  });
}
