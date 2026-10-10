import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_x_reply_composer.dart';
import 'package:quax/tweet/_x_repost_sheet.dart';
import 'package:quax/tweet/_x_tweet_layout.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_sheet.dart';
import 'package:quax/user.dart';

import '../home/x_pump.dart';
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'pump_tweets.dart';

TweetWithCard _tweet({int replies = 0, int favorites = 0, int views = 0}) => TweetWithCard()
  ..idStr = '100'
  ..fullText = 'Hello from the X design'
  ..text = 'Hello from the X design'
  ..displayTextRange = [0, 23]
  ..createdAt = DateTime.now().subtract(const Duration(hours: 2))
  ..user = (User()
    ..idStr = '1'
    ..name = 'Ada Lovelace'
    ..screenName = 'ada')
  ..replyCount = replies
  ..favoriteCount = favorites
  ..viewCount = views;

class _Recorder extends NavigatorObserver {
  final pushed = <RouteSettings>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route.settings);
}

Future<_Recorder> _pumpTile(WidgetTester tester, TweetWithCard tweet) async {
  final recorder = _Recorder();
  await pumpInApp(
      tester,
      withAppModels(SingleChildScrollView(child: TweetTile(clickable: true, tweet: tweet))),
      settle: false,
      prefs: {optionXStyle: true},
      navigatorObservers: [recorder],
      onGenerateRoute: (settings) =>
          MaterialPageRoute(settings: settings, builder: (_) => Scaffold(body: Text('route ${settings.name}'))));
  recorder.pushed.clear();
  return recorder;
}

StatusScreenArguments _lastStatus(_Recorder recorder) =>
    recorder.pushed.single.arguments as StatusScreenArguments;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  group('Tap on the card', () {
    testWidgets('Should open the post when the card is tapped where nothing else is', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tapAt(tester.getBottomLeft(find.byType(XTweetLayout)) + const Offset(100, -2));
      await tester.pump();

      expect(recorder.pushed.single.name, routeStatus, reason: 'Tapping the card opens the post');
      expect(_lastStatus(recorder).id, '100', reason: 'It is the tapped post that opens');
      expect(_lastStatus(recorder).focusReply, isFalse, reason: 'A plain tap does not start a reply');
    });

    testWidgets('Should open the profile and not the post when the avatar is tapped', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tap(find.byType(UserAvatar));
      await tester.pump();

      expect(recorder.pushed.single.name, routeProfile, reason: 'The avatar keeps its own action');
    });

    testWidgets('Should open the post with the reply field focused from the reply button', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tap(find.byIcon(XIcons.reply));
      await tester.pump();

      expect(recorder.pushed.single.name, routeStatus, reason: 'The reply button opens the post');
      expect(_lastStatus(recorder).focusReply, isTrue, reason: 'It asks for the reply field to be focused');
    });

    testWidgets('Should offer to repost or quote from the repost button', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tap(find.byIcon(XIcons.repost));
      await tester.pumpAndSettle();

      expect(find.text('Repost'), findsOneWidget, reason: 'The sheet offers to repost');
      expect(find.text('Quote'), findsOneWidget, reason: 'The sheet offers to quote');
      expect(recorder.pushed.where((e) => e.name == routeStatus), isEmpty, reason: 'The post does not open');
    });
  });

  group('Repost sheet', () {
    testWidgets('Should be an X sheet with a Cancel button that closes it', (tester) async {
      await pumpXApp(
          tester,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => showXRepostSheet(context, tweetId: '100', screenName: 'ada'),
                  child: const Text('open sheet'))));
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(XSheet), findsOneWidget, reason: 'The sheet has the chrome of the X design');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Repost'), findsNothing, reason: 'Cancel closes the sheet');
    });

    testWidgets('Should open the repost and quote intents', (tester) async {
      final opened = <String>[];
      await pumpXApp(
          tester,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => showXRepostSheet(context,
                      tweetId: '100', screenName: 'ada', opener: (context, url) async => opened.add(url)),
                  child: const Text('open sheet'))));

      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Repost'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open sheet'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quote'));
      await tester.pumpAndSettle();

      expect(opened, [
        'https://x.com/intent/retweet?tweet_id=100',
        'https://x.com/intent/post?url=https%3A%2F%2Fx.com%2Fada%2Fstatus%2F100',
      ], reason: 'Each option hands over to its intent, closing the sheet');
      expect(find.text('Repost'), findsNothing, reason: 'The sheet closes');
    });
  });

  group('Reply composer', () {
    testWidgets('Should focus the field when asked to', (tester) async {
      await pumpXApp(tester, const Scaffold(bottomNavigationBar: XReplyComposer(tweetId: '100', autofocus: true)));

      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isTrue,
          reason: 'The reply starts ready to type');
      expect(find.text('Post your reply'), findsOneWidget, reason: 'The field invites to reply');
    });

    testWidgets('Should leave the field unfocused by default', (tester) async {
      await pumpXApp(tester, const Scaffold(bottomNavigationBar: XReplyComposer(tweetId: '100')));

      expect(tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus, isFalse,
          reason: 'Opening a post does not pop the keyboard up');
    });

    testWidgets('Should hand the text over to X and clear the field', (tester) async {
      final opened = <String>[];
      await pumpXApp(
          tester,
          Scaffold(
              bottomNavigationBar:
                  XReplyComposer(tweetId: '100', opener: (context, url) async => opened.add(url))));

      await tester.enterText(find.byType(TextField), 'Nice one, Ada!');
      await tester.tap(find.text('Reply'));
      await tester.pump();

      expect(opened, ['https://x.com/intent/post?in_reply_to=100&text=Nice%20one%2C%20Ada!'],
          reason: 'The reply goes through the web intent of X');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty,
          reason: 'The field is cleared once the text is handed over');
    });
  });

  group('Action bar width', () {
    for (final width in [320.0, 360.0]) {
      testWidgets('Should not overflow at ${width}dp with long counts', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 800);
        addTearDown(tester.view.reset);

        await _pumpTile(tester, _tweet(replies: 1200000, favorites: 4450, views: 123400)..retweetCount = 4450);

        expect(tester.takeException(), isNull, reason: 'The action bar must fit $width dp');
        expect(find.byIcon(XIcons.share), findsOneWidget, reason: 'The whole bar is still there');
      });
    }

    testWidgets('Should line the reply icon up with the content column', (tester) async {
      await _pumpTile(tester, _tweet());

      expect(tester.getTopLeft(find.byIcon(XIcons.reply)).dx, xTweetContentLeft,
          reason: 'The first action has no padding on its left');
    });
  });
}
