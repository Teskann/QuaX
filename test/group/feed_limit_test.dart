import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/group/feed_chunk.dart';
import 'package:quax/group/feed_limit.dart';

import '../ui/pump_app.dart';
import 'open_feed.dart';

// Without replies, the same account makes a search of its own
final _twoChunks = [
  flutterDevChunk,
  SharedSearchFeedChunk([flutterDev], includeReplies: false, includeRetweets: true),
];

Future<void> _openTheConfirmation(WidgetTester tester) async {
  await pumpInApp(tester, const FeedLimitWarning(loadedSubscriptions: 128, totalSubscriptions: 300));
  await tester.tap(find.widgetWithText(TextButton, 'Load the whole feed'));
  await tester.pumpAndSettle();
}

bool _limitLifted(WidgetTester tester) =>
    PrefService.of(tester.element(find.byType(FeedLimitWarning))).get<bool>(optionUnlimitedFeeds) ?? false;

void main() {
  test('Should only load the first chunk of a feed, and warn about the others', () {
    final feed = limitFeed(_twoChunks, lifted: false);

    expect(feed.chunks, [_twoChunks.first], reason: 'Only the first chunk should load while the limit is on');
    final warning = feed.warning as FeedLimitWarning?;
    expect(warning?.loadedSubscriptions, 1, reason: 'The warning should count the subscriptions that load');
    expect(warning?.totalSubscriptions, 2, reason: 'The warning should count every subscription of the feed');
  });

  test('Should not warn about a feed made of one chunk', () {
    final feed = limitFeed([flutterDevChunk], lifted: false);

    expect(feed.chunks, [flutterDevChunk], reason: 'A feed of one chunk loads in full anyway');
    expect(feed.warning, isNull, reason: 'Nothing is left out, so there is nothing to warn about');
  });

  test('Should load the whole feed without warning once the user lifted the limit', () {
    final feed = limitFeed(_twoChunks, lifted: true);

    expect(feed.chunks, _twoChunks, reason: 'A user who accepted the risk should get the whole feed back');
    expect(feed.warning, isNull, reason: 'The user already accepted the risk');
  });

  testWidgets('Should explain the limit and invite to discuss it on Discord', (tester) async {
    await pumpInApp(tester, const FeedLimitWarning(loadedSubscriptions: 128, totalSubscriptions: 300));

    expect(find.text('Feed limited to protect your account'), findsOneWidget,
        reason: 'The title should say why part of the feed is missing');
    expect(find.textContaining('Subscriptions loaded: 128/300'), findsOneWidget,
        reason: 'The user should see how much of the feed is left out');
    expect(find.widgetWithText(FilledButton, 'Discuss on Discord'), findsOneWidget,
        reason: 'Talking with us is the main action while we look for a better solution');
    expect(find.widgetWithText(TextButton, 'Load the whole feed'), findsOneWidget,
        reason: 'Lifting the limit should stay possible, as a minor action');
  });

  testWidgets('Should keep the limit when the user cancels the warning about suspension', (tester) async {
    await _openTheConfirmation(tester);
    expect(find.text('I accept the risk'), findsOneWidget, reason: 'The user should confirm before taking the risk');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(_limitLifted(tester), isFalse, reason: 'Cancelling should leave the feed limited');
  });

  testWidgets('Should lift the limit once the user accepts the risk', (tester) async {
    await _openTheConfirmation(tester);

    await tester.tap(find.text('I accept the risk'));
    await tester.pumpAndSettle();

    expect(_limitLifted(tester), isTrue, reason: 'The choice should be saved so that every feed loads in full');
  });
}
