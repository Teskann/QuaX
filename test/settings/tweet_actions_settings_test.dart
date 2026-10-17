import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/settings/_tweet_actions.dart';
import 'package:quax/tweet/tweet_actions.dart';

import '../tweet/pump_tweets.dart';
import '../ui/pump_app.dart';

/// Tall enough for every row of the list to be built.
Future<void> pumpSettings(WidgetTester tester, TweetActionsConfig stored) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return pumpInApp(
    tester,
    withAppModels(const SettingsTweetActionsFragment()),
    prefs: {optionTweetActions: stored.encode()},
  );
}

TweetActionsConfig storedConfig(WidgetTester tester) => parseTweetActions(
  PrefService.of(
    tester.element(find.byType(SettingsTweetActionsFragment)),
    listen: false,
  ).get<String>(optionTweetActions),
);

void main() {
  testWidgets('Should badge the new buttons during the first visit only', (tester) async {
    await pumpSettings(tester, legacyTweetActionsConfig);

    expect(find.text('New'), findsNWidgets(4), reason: 'The four buttons added since the legacy bar are new');
    expect(
      storedConfig(tester).newActions,
      isEmpty,
      reason: 'Opening the page should store every action, so nothing is new on the next visit',
    );
  });

  testWidgets('Should show a switched on button in the preview and store it', (tester) async {
    await pumpSettings(tester, defaultTweetActions);
    expect(find.byIcon(Icons.link), findsOneWidget, reason: 'Only the row should show the hidden copy link button');

    await tester.tap(find.text('Copy post link'));
    await tester.pumpAndSettle();

    expect(storedConfig(tester).enabled, contains(TweetAction.copyLink), reason: 'The switch should be stored');
    expect(find.byIcon(Icons.link), findsNWidgets(2), reason: 'The preview should now show the button too');
  });

  testWidgets('Should reset the bar to its default', (tester) async {
    await pumpSettings(tester, defaultTweetActions.withToggled(TweetAction.reply).withMoved(5, 0));

    await tester.tap(find.byTooltip('Reset to default'));
    await tester.pumpAndSettle();

    expect(
      storedConfig(tester).encode(),
      defaultTweetActions.encode(),
      reason: 'Reset should bring back the default order and visibility',
    );
  });
}
