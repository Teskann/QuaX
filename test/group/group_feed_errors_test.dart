import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/tweet/conversation.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'open_feed.dart';

/// The tweets stored for the chunk, which the feed shows while X does not answer.
Future<int> _storedChunks(WidgetTester tester) async => (await tester.runAsync(() async {
      final database = await Repository.readOnly();
      return (await database.query(tableFeedGroupChunk, where: 'hash = ?', whereArgs: [flutterDevChunk.hash])).length;
    }))!;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());
  useFreshDatabase();

  testWidgets('Should show an error X answered to a feed as a bug to report, and keep the stored tweets',
      (tester) async {
    final stored = Twitter.parseSearchTimeline(
        fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body);
    await tester.runAsync(() async {
      final database = await Repository.writable();
      await database.insert(tableFeedGroupChunk, {
        'hash': flutterDevChunk.hash,
        'response': jsonEncode(stored.chains.map((e) => e.toJson()).toList()),
      });
    });

    await openFeed(tester, FixtureTwitterClient({'SearchTimeline': fixture('SearchTimeline', 'min-faves-10000', unstable: true)}));

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

    await openFeed(
        tester, FixtureTwitterClient({'SearchTimeline': answering(recorded, withXError(recorded.body, internalXError))}));

    expect(find.byType(TweetConversation), findsWidgets, reason: 'The tweets X sent should still be listed');
    expect(find.text('𝕏 returned an error'), findsOneWidget, reason: 'What X reported wrong should not be hidden');
  });
}
