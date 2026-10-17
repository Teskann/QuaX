import 'package:dart_twitter_api/twitter_api.dart' show User;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/tweet/tweet_actions.dart';

import '../ui/pump_app.dart';
import 'pump_tweets.dart';

TweetWithCard textTweet() => TweetWithCard()
  ..idStr = '42'
  ..fullText = 'Hello'
  ..displayTextRange = [0, 5]
  ..createdAt = DateTime(2026, 1, 1)
  ..replyCount = 1
  ..retweetCount = 2
  ..quoteCount = 0
  ..favoriteCount = 3
  ..viewCount = 4
  ..user = (User()
    ..idStr = '1'
    ..name = 'Someone'
    ..screenName = 'someone');

Future<void> pumpTweet(WidgetTester tester, TweetActionsConfig config) => pumpInApp(
  tester,
  withAppModels(TweetTile(clickable: true, tweet: textTweet())),
  prefs: {optionTweetActions: config.encode()},
);

double leftOf(WidgetTester tester, IconData icon) => tester.getTopLeft(find.byIcon(icon)).dx;

void main() {
  testWidgets('Should show only the enabled buttons, in their order', (tester) async {
    await pumpTweet(
      tester,
      defaultTweetActions.withToggled(TweetAction.views).withToggled(TweetAction.copyLink).withMoved(7, 0),
    );

    expect(find.byIcon(Icons.bar_chart), findsNothing, reason: 'Views were hidden');
    expect(find.byIcon(Icons.link), findsOneWidget, reason: 'Copy link was enabled');
    expect(
      leftOf(tester, Icons.link),
      lessThan(leftOf(tester, Icons.mode_comment_outlined)),
      reason: 'Copy link was moved before replies',
    );
  });

  testWidgets('Should list the hidden buttons in the more menu', (tester) async {
    await pumpTweet(tester, defaultTweetActions.withToggled(TweetAction.more));

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Copy post link'), findsOneWidget, reason: 'A hidden button should be offered in the menu');
    expect(find.text('Download'), findsNothing, reason: 'A tweet without media has nothing to download');
    expect(find.text('Customize action bar'), findsOneWidget, reason: 'The menu should lead to the bar settings');
  });

  testWidgets('Should let the more menu scroll on a small screen', (tester) async {
    tester.view.physicalSize = const Size(400, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final onlyMore = TweetActionsConfig(
      TweetAction.values.map((a) => TweetActionSetting(a, a == TweetAction.more)).toList(),
    );
    await pumpTweet(tester, onlyMore);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Copy post text'), 100, scrollable: find.byType(Scrollable).last);

    expect(find.text('Copy post text'), findsOneWidget, reason: 'The last hidden button should be reachable');
    expect(find.text('Customize action bar'), findsOneWidget, reason: 'The link to the settings stays below the list');
  });

  testWidgets('Should not show the download button on a tweet without media', (tester) async {
    await pumpTweet(tester, defaultTweetActions.withToggled(TweetAction.download));

    expect(find.byIcon(Icons.download), findsNothing, reason: 'There is nothing to download');
  });

  testWidgets('Should hide the more button when no button is hidden', (tester) async {
    final allEnabled = TweetActionsConfig(TweetAction.values.map((a) => TweetActionSetting(a, true)).toList());
    await pumpTweet(tester, allEnabled);

    expect(find.byIcon(Icons.more_vert), findsNothing, reason: 'An empty menu is not worth a button');
  });

  testWidgets('Should copy the link of the tweet', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('browser_resolver'),
      (call) async => call.method == 'getSdkInt' ? 32 : null,
    );
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    await pumpTweet(tester, defaultTweetActions.withToggled(TweetAction.copyLink));

    await tester.tap(find.byIcon(Icons.link));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(copied, 'https://x.com/someone/status/42', reason: 'The link should point to the tweet on X');
    expect(find.text('Link copied'), findsOneWidget, reason: 'Copying should be confirmed');
  });

  testWidgets('Should leave the copy confirmation to Android from version 13', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('browser_resolver'),
      (call) async => call.method == 'getSdkInt' ? 33 : null,
    );
    await pumpTweet(tester, defaultTweetActions.withToggled(TweetAction.copyLink));

    await tester.tap(find.byIcon(Icons.link));
    await tester.pump();

    expect(find.text('Link copied'), findsNothing, reason: 'Android 13 already previews what was copied');
  });
}
