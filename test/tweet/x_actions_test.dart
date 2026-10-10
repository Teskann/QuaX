import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_x_tweet_layout.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_sheet.dart';
import 'package:quax/user.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

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

/// Records what is launched, and how, instead of leaving the app
class _FakeLauncher extends UrlLauncherPlatform {
  final launched = <({String url, PreferredLaunchMode mode})>[];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add((url: url, mode: options.mode));
    return true;
  }
}

void main() {
  late _FakeLauncher launcher;

  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  setUp(() {
    launcher = _FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  group('Tap on the card', () {
    testWidgets('Should open the post when the card is tapped where nothing else is', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tapAt(tester.getBottomLeft(find.byType(XTweetLayout)) + const Offset(100, -2));
      await tester.pump();

      expect(recorder.pushed.single.name, routeStatus, reason: 'Tapping the card opens the post');
      expect(_lastStatus(recorder).id, '100', reason: 'It is the tapped post that opens');
    });

    testWidgets('Should open the profile and not the post when the avatar is tapped', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tap(find.byType(UserAvatar));
      await tester.pump();

      expect(recorder.pushed.single.name, routeProfile, reason: 'The avatar keeps its own action');
    });

    testWidgets('Should open the post in X from the reply button, without opening it in QuaX', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tap(find.byIcon(XIcons.reply));
      await tester.pump();

      expect(launcher.launched, [(url: 'https://x.com/ada/status/100', mode: PreferredLaunchMode.externalApplication)],
          reason: 'The reply button hands the post over to the X app, or the browser');
      expect(recorder.pushed, isEmpty, reason: 'QuaX cannot reply, so its own post screen does not open');
    });

    testWidgets('Should open the post in X from the repost button, without any sheet', (tester) async {
      final recorder = await _pumpTile(tester, _tweet());

      await tester.tap(find.byIcon(XIcons.repost));
      await tester.pumpAndSettle();

      expect(launcher.launched, [(url: 'https://x.com/ada/status/100', mode: PreferredLaunchMode.externalApplication)],
          reason: 'One tap on repost opens the post in the X app, or the browser');
      expect(find.byType(XSheet), findsNothing, reason: 'There is no repost or quote sheet anymore');
      expect(recorder.pushed, isEmpty, reason: 'The post does not open in QuaX');
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
