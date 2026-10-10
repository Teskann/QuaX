import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/_expandable_tweet_text.dart';
import 'package:quax/tweet/_photo.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/formats.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'pump_tweets.dart';

Future<void> pumpPhoto(WidgetTester tester, {required bool fullscreen}) => pumpInApp(
      tester,
      Center(
        child: SizedBox(
          width: 300,
          height: 200,
          child: TweetPhoto(
              uri: 'https://pbs.twimg.com/media/photo.jpg',
              size: 'medium',
              pullToClose: fullscreen,
              inPageView: fullscreen,
              fullscreen: fullscreen),
        ),
      ),
      settle: false,
    );

Future<void> pumpText(WidgetTester tester, double width, String text, {bool selectable = false}) => pumpInApp(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: ExpandableTweetText(
              textSpans: [TextSpan(text: text)], maxLines: 3, selectable: selectable, fadeColor: Colors.white),
        ),
      ),
      settle: false,
    );

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  group('Tweet card color', () {
    test('Should give the very same color for the same inputs', () {
      final first = cardColorFor(seed: Colors.teal, brightness: Brightness.light, trueBlack: false);
      final second = cardColorFor(seed: Colors.teal, brightness: Brightness.light, trueBlack: false);

      expect(identical(first, second), isTrue, reason: 'The color should come from the memo, not be built again');
    });

    test('Should give another color when the seed or the brightness change', () {
      final base = cardColorFor(seed: Colors.teal, brightness: Brightness.light, trueBlack: false);

      expect(cardColorFor(seed: Colors.deepOrange, brightness: Brightness.light, trueBlack: false), isNot(base),
          reason: 'Another seed should not reuse the memoized color');
      expect(cardColorFor(seed: Colors.teal, brightness: Brightness.dark, trueBlack: false), isNot(base),
          reason: 'Another brightness should not reuse the memoized color');
    });

    test('Should be black in true black mode whatever the seed', () {
      expect(cardColorFor(seed: Colors.teal, brightness: Brightness.dark, trueBlack: true), Colors.black,
          reason: 'True black cards should be black');
    });
  });

  group('Photo', () {
    testWidgets('Should decode a feed photo at the size it is laid out, without gestures', (tester) async {
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpPhoto(tester, fullscreen: false);

      final image = tester.widget<ExtendedImage>(find.byType(ExtendedImage));
      expect(image.mode, ExtendedImageMode.none, reason: 'A feed photo needs no zoom gestures');
      expect((image.image as ExtendedResizeImage).width, 600, reason: 'The decode width is the layout width in pixels');
      expect(find.byType(ExtendedImageSlidePage), findsNothing, reason: 'A feed photo cannot be slid out');
    });

    testWidgets('Should keep gestures and slide out in the full-screen viewer', (tester) async {
      await pumpPhoto(tester, fullscreen: true);

      final image = tester.widget<ExtendedImage>(find.byType(ExtendedImage));
      expect(image.mode, ExtendedImageMode.gesture, reason: 'The viewer should zoom');
      expect(find.byType(ExtendedImageSlidePage), findsOneWidget, reason: 'The viewer should slide out');
    });
  });

  group('Expandable tweet text', () {
    const long = 'A long text that goes over several lines once it is laid out in a narrow box, again and again and again';

    setUp(TruncationCache.clear);

    testWidgets('Should measure once for the same text and constraints', (tester) async {
      await pumpText(tester, 150, long);
      await pumpText(tester, 150, long);
      await tester.pump();

      expect(TruncationCache.measureCount, 1, reason: 'Laying out again with the same inputs should hit the cache');
      expect(find.text('Show more'), findsOneWidget, reason: 'The long text should be truncated');
    });

    testWidgets('Should measure again when the width changes', (tester) async {
      await pumpText(tester, 150, long);
      await pumpText(tester, 160, long);

      expect(TruncationCache.measureCount, 2, reason: 'Another width can break lines differently');
    });

    testWidgets('Should fade with a gradient instead of a shader mask', (tester) async {
      await pumpText(tester, 150, long);

      expect(find.byType(ShaderMask), findsNothing, reason: 'A shader mask forces an offscreen layer');
      final gradients = find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).gradient != null);
      expect(gradients, findsOneWidget, reason: 'The truncated text should fade out');
    });

    testWidgets('Should only be selectable when asked to', (tester) async {
      await pumpText(tester, 150, long);
      expect(find.byType(SelectableText), findsNothing, reason: 'Feed text should be a plain text');

      await pumpText(tester, 150, long, selectable: true);
      expect(find.byType(SelectableText), findsOneWidget, reason: 'The text should be selectable when asked to');
    });
  });

  group('Formats', () {
    test('Should build the compact number format once per locale', () {
      final original = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = original);

      Intl.defaultLocale = 'en';
      final english = compactNumberFormat();
      expect(identical(compactNumberFormat(), english), isTrue, reason: 'The same locale should reuse the format');

      Intl.defaultLocale = 'fr';
      final french = compactNumberFormat();
      expect(identical(french, english), isFalse, reason: 'Another locale needs its own format');
      expect(identical(compactNumberFormat(), french), isTrue, reason: 'Each locale should be remembered');
    });

    test('Should parse locale names', () {
      expect(parseLocale('pt_BR'), const Locale('pt', 'BR'), reason: 'Underscore separated names should be split');
      expect(parseLocale('en'), const Locale('en'), reason: 'A language alone should have no country');
      expect(identical(parseLocale('pt_BR'), parseLocale('pt_BR')), isTrue, reason: 'The parsed locale is remembered');
    });
  });

  group('Avatar', () {
    testWidgets('Should be clipped once in a tweet tile', (tester) async {
      const id = '2095918742400082069';
      await pumpChains(tester, Twitter.parseTweetDetail(fixture('TweetDetail', id).body).chains);

      final avatar = find.descendant(of: tweetTile(id), matching: find.byType(UserAvatar)).first;
      expect(find.ancestor(of: avatar, matching: find.byType(ClipRRect)), findsNothing,
          reason: 'The tile should not clip what the avatar already clips');
      expect(find.descendant(of: avatar, matching: find.byType(ClipRRect)), findsOneWidget,
          reason: 'The avatar should clip itself once');
    });
  });
}
