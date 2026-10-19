import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/errors.dart';

import 'pump_app.dart';

Future<void> pumpCard(WidgetTester tester, Object error) =>
    pumpInApp(tester, ErrorCard(error: error, stackTrace: null, prefix: (_) => 'Unable to load', onRetry: () {}));

void main() {
  testWidgets('Should offer to report an unexpected error, and to retry', (tester) async {
    await pumpCard(tester, StateError('boom'));

    expect(find.text('Unable to load'), findsOneWidget, reason: 'The title should say what failed');
    expect(find.text('Bad state: boom'), findsOneWidget, reason: 'The technical reason should be shown below');
    expect(find.widgetWithText(FilledButton, 'Report'), findsOneWidget,
        reason: 'An unexpected error is a bug, so reporting it is the primary action');
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget, reason: 'Retrying should stay available');
  });

  testWidgets('Should offer to add an account rather than to report a rate limit', (tester) async {
    await pumpCard(tester, RateLimitedException());

    expect(find.widgetWithText(FilledButton, 'Add account'), findsOneWidget,
        reason: 'Another account is what gets the user past a rate limit');
    expect(find.text('Report'), findsNothing, reason: 'A rate limit is not a bug, reports would only be noise');
    expect(find.text('Unable to load'), findsNothing,
        reason: 'The rate limit title explains the problem better than the generic message');
  });

  testWidgets('Should tell how much of a feed could load when some of its searches were rate limited', (tester) async {
    await pumpCard(tester, FeedRateLimitedException(DateTime.now(), loaded: 128, total: 300));

    expect(find.text('The whole feed could not be loaded'), findsOneWidget,
        reason: 'Part of the feed is shown, so the title should say it is incomplete rather than only rate limited');
    expect(find.textContaining('Try again at '), findsOneWidget,
        reason: 'X said when the quota comes back, so the user should know when to retry');
    expect(find.textContaining('Subscriptions loaded: 128/300'), findsOneWidget,
        reason: 'The user should see how much of the feed is missing, which hints at too many subscriptions');
    expect(find.widgetWithText(FilledButton, 'Add account'), findsOneWidget,
        reason: 'Another account raises the quota, which is what gets the whole feed loaded');
  });

  testWidgets('Should only offer to retry when X answers 404', (tester) async {
    await pumpCard(tester, NotFoundException());

    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget,
        reason: 'A 404 happens now and then in normal use and retrying is the only useful action, '
            'so it is the main one');
    expect(find.widgetWithText(TextButton, 'Retry'), findsNothing, reason: 'Retry should not be offered twice');
    expect(find.text('Add account'), findsNothing, reason: 'A 404 does not mean the accounts are broken');
    expect(find.text('Report'), findsNothing, reason: 'A 404 is expected from X, not a bug of the app');
  });

  testWidgets('Should tell when a rate limit ends, if X told us', (tester) async {
    await pumpCard(tester, RateLimitedException(DateTime.now().add(const Duration(minutes: 10))));

    expect(find.textContaining('Rate limited by 𝕏 until'), findsOneWidget,
        reason: 'The title should tell when the quota comes back, so the user can decide between waiting and '
            'adding an account');
  });

  testWidgets('Should not tell when a rate limit ends, if X did not say', (tester) async {
    await pumpCard(tester, RateLimitedException());

    expect(find.text('Rate limited by 𝕏'), findsOneWidget,
        reason: 'Without a reset time from X there is nothing reliable to show, so the plain title should stay');
  });

  testWidgets('Should look like a tweet, with a bright red icon', (tester) async {
    await pumpCard(tester, StateError('boom'));

    final context = tester.element(find.byType(ErrorCard));
    final colors = Theme.of(context).colorScheme;
    final red = Colors.red.harmonizeWith(colors.primary);
    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, red,
        reason: 'The icon should use a red brighter than the error color of the theme');
    expect(tester.widget<Card>(find.byType(Card)).color, tweetCardColor(context),
        reason: 'The card sits among tweets, so it should share their background, true black mode included');
  });

  testWidgets('Should unfold long details when tapped, and fold them back on a second tap', (tester) async {
    final details = List.filled(15, 'Something went really wrong.').join(' ');
    await pumpCard(tester, StateError(details));

    Text detailsText() => tester.widget<Text>(find.textContaining('Something went'));
    expect(detailsText().maxLines, 2, reason: 'Long details should first be clamped to keep the card compact');

    await tester.tap(find.textContaining('Something went'));
    await tester.pumpAndSettle();
    expect(detailsText().maxLines, isNull, reason: 'Tapping the details should reveal them entirely');

    await tester.tap(find.textContaining('Something went'));
    await tester.pumpAndSettle();
    expect(detailsText().maxLines, 2, reason: 'Tapping again should fold the details back');
  });

  testWidgets('Should not offer to unfold details that already fit', (tester) async {
    await pumpCard(tester, StateError('boom'));

    expect(find.ancestor(of: find.text('Bad state: boom'), matching: find.byType(GestureDetector)), findsNothing,
        reason: 'Short details should not react to taps');
  });

  testWidgets('Should keep buttons smaller than the title, with as much space below them as above the title',
      (tester) async {
    await pumpInApp(
        tester,
        SingleChildScrollView(
            child: ErrorCard(
                error: StateError('boom'), stackTrace: null, prefix: (_) => 'Unable to load', onRetry: () {})));

    double fontSize(Finder finder) => tester.renderObject<RenderParagraph>(finder).text.style!.fontSize!;
    final title = fontSize(find.text('Unable to load'));
    expect(fontSize(find.text('Report')), lessThan(title), reason: 'The primary button should not outweigh the title');
    expect(fontSize(find.text('Retry')), lessThan(title), reason: 'The retry button should not outweigh the title');

    final card = tester.getRect(find.byType(Card));
    final top = tester.getRect(find.byIcon(Icons.error_outline)).top - card.top;
    final bottom = card.bottom - tester.getRect(find.byType(FilledButton)).bottom;
    expect(bottom, top, reason: 'The space under the buttons should match the one above the title');
  });
}
