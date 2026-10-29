import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/_feed.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';

final _flutterDev = UserSubscription(
    id: '420730316',
    screenName: 'FlutterDev',
    name: 'Flutter',
    profileImageUrlHttps: null,
    verified: false,
    createdAt: DateTime(2024),
    inFeed: true);

final _chunk = SubscriptionGroupFeedChunk([_flutterDev], true, true);

/// Opens a feed made of one chunk, whose search X answers with [answer].
Future<void> _openFeed(WidgetTester tester, Fixture answer) async {
  Twitter.client = FixtureTwitterClient({'SearchTimeline': answer});
  await pumpInApp(
      tester,
      withAppModels(SubscriptionGroupFeed(
          group: SubscriptionGroupGet(
              id: 'group',
              name: 'Group',
              icon: '',
              subscriptions: [_flutterDev],
              includeReplies: true,
              includeRetweets: true),
          chunks: [_chunk],
          includeReplies: true,
          includeRetweets: true)),
      settle: false);
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The tweets stored for the chunk, which the feed shows while X does not answer.
Future<int> _storedChunks(WidgetTester tester) async => (await tester.runAsync(() async {
      final database = await Repository.readOnly();
      return (await database.query(tableFeedGroupChunk, where: 'hash = ?', whereArgs: [_chunk.hash])).length;
    }))!;

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await databaseFactory.deleteDatabase(databaseName);
    await Repository().migrate();
  });

  testWidgets('Should show an error X answered to a feed as a bug to report, and keep the stored tweets',
      (tester) async {
    final stored = Twitter.parseSearchTimeline(
        fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body);
    await tester.runAsync(() async {
      final database = await Repository.writable();
      await database.insert(tableFeedGroupChunk, {
        'cursor_id': 1,
        'hash': _chunk.hash,
        'response': jsonEncode(stored.chains.map((e) => e.toJson()).toList()),
      });
    });

    await _openFeed(tester, fixture('SearchTimeline', 'min-faves-10000', unstable: true));

    expect(find.text('𝕏 returned an error'), findsOneWidget,
        reason: 'QuaX built the query of the feed, so a query X refuses is a bug of QuaX');
    expect(find.text('𝕏 rejected this search'), findsNothing,
        reason: 'The user typed no search in a feed, so they should not be told to change it');
    expect(find.text('Report'), findsOneWidget, reason: 'A query of QuaX that X refuses should be reported');
    expect(await _storedChunks(tester), 1,
        reason: 'X sent no tweet, so the tweets stored for the chunk should be kept');
  });

  testWidgets('Should show the tweets X sent to a feed along with an error, and the error above them', (tester) async {
    final recorded = fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true);

    await _openFeed(tester, answering(recorded, withXError(recorded.body, internalXError)));

    expect(find.byType(TweetConversation), findsWidgets, reason: 'The tweets X sent should still be listed');
    expect(find.text('𝕏 returned an error'), findsOneWidget, reason: 'What X reported wrong should not be hidden');
  });
}
