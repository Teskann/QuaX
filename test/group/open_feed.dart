import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/_feed.dart';
import 'package:quax/group/feed_scroll_controller.dart';
import 'package:quax/group/group_screen.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../tweet/pump_tweets.dart';
import '../ui/pump_app.dart';

final flutterDev = UserSubscription(
    id: '420730316',
    screenName: 'FlutterDev',
    name: 'Flutter',
    profileImageUrlHttps: null,
    verified: false,
    createdAt: DateTime(2024),
    inFeed: true);

final flutterDevChunk = SubscriptionGroupFeedChunk([flutterDev], true, true);

/// Opens the main feed, made of [flutterDevChunk], with videos turned off.
Future<void> openFeed(WidgetTester tester, AbstractTwitterClient client,
    {bool keepPosition = false, FeedScrollController? scrollController}) async {
  Twitter.client = client;
  await pumpInApp(
      tester,
      InheritedProvider<FeedScrollController>.value(
        value: scrollController ?? FeedScrollController(),
        child: withAppModels(SubscriptionGroupFeed(
          group: SubscriptionGroupGet(
              id: '-1',
              name: 'Group',
              icon: '',
              subscriptions: [flutterDev],
              includeReplies: true,
              includeRetweets: true),
          chunks: [flutterDevChunk],
          includeReplies: true,
          includeRetweets: true)),
      ),
      settle: false,
      prefs: {optionMediaDisableAutoload: true, optionKeepFeedOffset: keepPosition});
  await settleFeed(tester);
}

/// Waits for the database and X to answer.
Future<void> settleFeed(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Gives each test file its own database, because test files run in parallel.
void useFreshDatabase() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.setDatabasesPath(Directory.systemTemp.createTempSync('quax-feed').path);
  });

  setUp(() async {
    await databaseFactory.deleteDatabase(databaseName);
    await Repository().migrate();
  });
}
