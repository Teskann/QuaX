import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/tweet/_x_tweet_layout.dart';

import '../ui/pump_app.dart';

void main() {
  group('xRelativeTime', () {
    final now = DateTime(2026, 10, 9, 12);

    test('Should count seconds under a minute', () {
      expect(xRelativeTime(now.subtract(const Duration(seconds: 42)), now), '42s',
          reason: 'X writes recent posts in seconds');
    });

    test('Should never show a negative age for a post dated in the future', () {
      expect(xRelativeTime(now.add(const Duration(seconds: 5)), now), '0s',
          reason: 'A clock slightly ahead must not print a minus sign');
    });

    test('Should count minutes under an hour', () {
      expect(xRelativeTime(now.subtract(const Duration(minutes: 59)), now), '59m',
          reason: 'X writes posts of the last hour in minutes');
    });

    test('Should count hours under a day', () {
      expect(xRelativeTime(now.subtract(const Duration(hours: 23)), now), '23h',
          reason: 'X writes posts of the last day in hours');
    });

    test('Should show the day without the year for older posts of this year', () {
      expect(xRelativeTime(DateTime(2026, 3, 4, 12), now), 'Mar 4',
          reason: 'X leaves the current year out');
    });

    test('Should show the year for posts of another year', () {
      expect(xRelativeTime(DateTime(2024, 3, 4, 12), now), 'Mar 4, 2024',
          reason: 'X adds the year once it is not the current one');
    });
  });

  group('XTranslateButton', () {
    testWidgets('Should show a spinner while translating', (tester) async {
      await pumpInApp(tester, const XTranslateButton(action: null), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: 'A loading translation shows progress');
      expect(find.byIcon(Icons.translate), findsNothing, reason: 'The button cannot be tapped while translating');
    });

    testWidgets('Should run its action when tapped', (tester) async {
      var tapped = false;
      await pumpInApp(tester, XTranslateButton(action: (color: null, onTap: () => tapped = true)));

      await tester.tap(find.byIcon(Icons.translate));

      expect(tapped, isTrue, reason: 'Tapping the icon should translate the post');
    });

    testWidgets('Should use the color of its action', (tester) async {
      await pumpInApp(tester, XTranslateButton(action: (color: Colors.red, onTap: () {})));

      expect(tester.widget<Icon>(find.byIcon(Icons.translate)).color, Colors.red,
          reason: 'A failed or done translation is told apart by its color');
    });
  });

  group('XTweetHeader', () {
    testWidgets('Should put the trailing widget at the right end of the line', (tester) async {
      await pumpInApp(
          tester, const XTweetHeader(name: 'Ada', handle: 'ada', time: '2h', trailing: Icon(Icons.translate)));

      expect(tester.getTopRight(find.byIcon(Icons.translate)).dx,
          moreOrLessEquals(tester.getTopRight(find.byType(XTweetHeader)).dx, epsilon: 1),
          reason: 'The trailing icon sits where X puts its menu');
    });

    testWidgets('Should keep the time readable when a long handle has to be cut', (tester) async {
      await pumpInApp(
          tester,
          const SizedBox(
              width: 220,
              child: XTweetHeader(name: 'Ada', handle: 'a_really_long_handle_that_cannot_fit', time: '2h')));

      expect(find.text(' · 2h'), findsOneWidget, reason: 'The handle gives way before the time');
      expect(tester.takeException(), isNull, reason: 'A long handle must not overflow the line');
    });

    testWidgets('Should show only the time when the author is hidden', (tester) async {
      await pumpInApp(tester, const XTweetHeader(time: '2h'));

      expect(find.text('2h'), findsOneWidget, reason: 'A hidden author leaves just the time, with no separator');
    });
  });
}
