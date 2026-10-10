import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/_video_controls.dart';
import 'package:quax/tweet/video_controller_pool.dart';

import '../ui/pump_app.dart';
import 'fake_video_controller.dart';

void main() {
  const tweetId = 'tweet';
  final holder = Object();
  late VideoControllerPool pool;
  late ScrollController scroll;
  late FakeVideoController controller;

  TweetVideo media({required bool isGif, String? imageUrl}) => TweetVideo(
    username: 'quax',
    metadata: TweetVideoMetadata(1.0, imageUrl, () async => TweetVideoUrls('', null)),
    loop: isGif,
    alwaysPlay: isGif,
    disableControls: isGif,
    tweetId: tweetId,
  );

  // The tile is the first thing in the list, a screen-high spacer comes after it.
  Future<void> pumpTile(
    WidgetTester tester,
    TweetVideo tile, {
    double spacerAbove = 0,
    Map<String, dynamic> prefs = const {},
  }) async {
    scroll = ScrollController();
    addTearDown(scroll.dispose);
    await pumpInApp(
      tester,
      MultiProvider(
        providers: [
          Provider.value(value: pool),
          ChangeNotifierProvider(create: (_) => VideoContextState(true)),
        ],
        child: SingleChildScrollView(
          controller: scroll,
          child: Column(
            children: [
              SizedBox(height: spacerAbove),
              tile,
              const SizedBox(height: 3000),
            ],
          ),
        ),
      ),
      settle: false,
      prefs: prefs,
    );
  }

  // A removed tile still has a pause to deliver a moment later.
  Future<void> removeTile(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  // A GIF that is already loaded, so the pool hands it out straight away.
  Future<void> poolPlayingGif() async {
    controller = FakeVideoController(isPlaying: true);
    await pool.acquire(
      '$tweetId:0',
      holder,
      () async => PooledVideo(
        controller: controller,
        downloadUrl: null,
        qualities: const [],
        ready: Future.value(),
        pausableByPolicy: false,
      ),
    );
  }

  Future<void> scrollTo(WidgetTester tester, double offset) async {
    scroll.jumpTo(offset);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  setUp(() => pool = VideoControllerPool(maxSize: 2));

  group('Off screen GIF tile', () {
    testWidgets('Should show its poster without a spinner until it is on screen', (tester) async {
      await pumpTile(tester, media(isGif: true), spacerAbove: 3000);

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason:
            'Nothing is loading for a tile nobody sees yet: a spinner there would animate for as '
            'long as the tile is built',
      );
      expect(find.byType(GifBadge), findsOneWidget, reason: 'The poster of a GIF is labelled as such');
    });

    testWidgets('Should keep the spinner on a video that is not on screen yet', (tester) async {
      await pumpTile(tester, media(isGif: false), spacerAbove: 3000, prefs: {optionMediaDefaultAutoPlay: true});

      expect(
        find.byType(CircularProgressIndicator),
        findsOneWidget,
        reason: 'Only GIFs lose the spinner; a video tile is left as it was',
      );
    });
  });

  group('Poster image', () {
    testWidgets('Should decode at the size it is shown in physical pixels', (tester) async {
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(800, 1600);
      addTearDown(tester.view.reset);

      await pumpTile(tester, media(isGif: true, imageUrl: 'https://example.invalid/poster.jpg'), spacerAbove: 3000);

      final image = tester.widget<ExtendedImage>(find.byType(ExtendedImage)).image;
      expect(image, isA<ExtendedResizeImage>(), reason: 'A poster decoded at the full size of its file wastes memory');
      expect(
        (image as ExtendedResizeImage).width,
        800,
        reason: 'The tile is 400 logical pixels wide on a 2x screen, so 800 physical ones',
      );
    });
  });

  group('GIF playback', () {
    testWidgets('Should pause a GIF once it scrolls off screen', (tester) async {
      await poolPlayingGif();
      await pumpTile(tester, media(isGif: true));

      await scrollTo(tester, 2000);
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        controller.pauseCalls,
        1,
        reason: 'A GIF nobody can see should not keep decoding frames and draining the battery',
      );

      await removeTile(tester);
    });

    testWidgets('Should resume a GIF when it scrolls back on screen', (tester) async {
      await poolPlayingGif();
      await pumpTile(tester, media(isGif: true));
      await scrollTo(tester, 2000);
      await tester.pump(const Duration(milliseconds: 300));

      await scrollTo(tester, 0);

      expect(controller.playCalls, 1, reason: 'A GIF plays on its own, so coming back on screen restarts it');

      await removeTile(tester);
    });

    testWidgets('Should pause a GIF when its tile is removed', (tester) async {
      await poolPlayingGif();
      await pumpTile(tester, media(isGif: true));

      await removeTile(tester);

      expect(
        controller.pauseCalls,
        1,
        reason: 'A tile thrown away by a fling must not leave its GIF running in the pool',
      );
    });
  });
}
