import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/space/space.dart';
import 'package:quax/space/space_card.dart';
import 'package:quax/space/space_model.dart';
import 'package:quax/space/space_screen.dart';
import 'package:quax/tweet/_card.dart';

import '../community/pump_community.dart';
import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'recorded_spaces.dart';

Future<List<Route<dynamic>>> _openCard(WidgetTester tester, Space space) =>
    pumpRoute(tester, Scaffold(body: SpaceCard(id: space.id)), const RouteSettings(name: '/'));

SpaceScreenArguments _openedSpace(List<Route<dynamic>> pushed) =>
    pushed.single.settings.arguments as SpaceScreenArguments;

// The post that shared [recorded], as AudioSpaceById sends it along with the space
TweetWithCard _sharingPost(Fixture recorded) =>
    TweetWithCard.fromGraphqlJson(recorded.body['data']['audioSpace']['metadata']['tweet_results']['result']);

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());
  tearDown(SpaceModel.forgetKnownSpaces);

  group('SpaceCard', () {
    testWidgets('Should play the space at once when its listen button opens it', (tester) async {
      final space = spaceOf(recordedSpace(hasPlayableRecording));
      final pushed = await _openCard(tester, space);

      expect(find.text(space.title), findsOneWidget, reason: 'The card shows the title X sent for the space id');
      await tester.tap(find.byType(SpaceListenButton));
      await tester.pump();

      expect(pushed.map((route) => route.settings.name), [
        routeSpace,
      ], reason: 'A space with a recording should open its page to play it');
      expect(_openedSpace(pushed).id, space.id, reason: 'The page should open the space of the card');
      expect(_openedSpace(pushed).autoplay, isTrue, reason: 'Listening was asked for, so it should start');
    });

    testWidgets('Should only open the space, without playing it, when the rest of the card is tapped', (tester) async {
      final space = spaceOf(recordedSpace(hasPlayableRecording));
      final pushed = await _openCard(tester, space);

      await tester.tap(find.text(space.title));
      await tester.pump();

      expect(_openedSpace(pushed).id, space.id, reason: 'The whole card leads to the page of its space');
      expect(_openedSpace(pushed).autoplay, isFalse, reason: 'Looking at who hosts a space should not start the audio');
    });

    testWidgets('Should show a card scrolled back into view at once, and refresh it without a spinner', (tester) async {
      final space = spaceOf(recordedSpace(isLive));
      final x = mockOfX();
      await pumpRoute(
        tester,
        Scaffold(
          body: ListView(
            children: [
              SpaceCard(id: space.id),
              const SizedBox(height: 3000),
            ],
          ),
        ),
        const RouteSettings(name: '/'),
        client: x,
      );

      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pump();
      expect(find.byType(SpaceCard), findsNothing, reason: 'The feed drops the card once it is far off screen');
      await tester.drag(find.byType(ListView), const Offset(0, 2500));

      for (var frame = 0; frame < 5; frame++) {
        await tester.pump(const Duration(milliseconds: 40));
        expect(find.text(space.title), findsOneWidget, reason: 'The known space should stay on screen in every frame');
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: 'A loading card has another height, which makes the feed jump while scrolling up',
        );
      }
      expect(
        x.answers.where((answer) => answer.fixture?.contains('AudioSpaceById') ?? false),
        hasLength(2),
        reason: 'The space is asked again, so a live one does not stay live forever',
      );
    });

    testWidgets('Should not offer to listen when there is no recording', (tester) async {
      await _openCard(tester, spaceOf(recordedSpace(hasNoRecording)));

      final button = tester.widget<FilledButton>(
        find.descendant(of: find.byType(SpaceListenButton), matching: find.byWidgetPredicate((w) => w is FilledButton)),
      );
      expect(button.onPressed, isNull, reason: 'An ended space without recording has nothing to play');
    });
  });

  group('TweetCard', () {
    testWidgets('Should show the space a post shares', (tester) async {
      final post = _sharingPost(recordedSpace((space) => true));
      await pumpRoute(
        tester,
        Scaffold(
          body: TweetCard(tweet: post, card: post.card),
        ),
        const RouteSettings(name: '/'),
      );

      expect(find.byType(SpaceCard), findsOneWidget, reason: 'X names the card of a space 3691233323:audiospace');
    });

    testWidgets('Should say a space card is unsupported when X left out the id of the space', (tester) async {
      final post = _sharingPost(recordedSpace((space) => true));
      final card = {...post.card!, 'binding_values': <String, dynamic>{}};
      await pumpRoute(
        tester,
        Scaffold(
          body: TweetCard(tweet: post, card: card),
        ),
        const RouteSettings(name: '/'),
      );

      expect(find.byType(SpaceCard), findsNothing, reason: 'Without its id, the space cannot be loaded');
      expect(find.text('Unsupported card'), findsOneWidget, reason: 'The post should still say a card is missing');
    });
  });
}
