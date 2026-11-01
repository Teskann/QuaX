import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/tweet/conversation.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'open_feed.dart';

Future<void> _storePage(WidgetTester tester, String cursor) => tester.runAsync(() async {
      final page = Twitter.parseSearchTimeline(
          fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body);
      await storeChunkPage(await Repository.writable(), flutterDevChunk.hash,
          TweetStatus(chains: page.chains, cursorBottom: cursor, cursorTop: null),
          firstPage: true);
    });

String? _sentCursor(Uri uri) => jsonDecode(uri.queryParameters['variables']!)['cursor'] as String?;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());
  useFreshDatabase();

  testWidgets('Should show the stored tweets when the feed opens and reload them from X', (tester) async {
    await _storePage(tester, 'stored');
    final sent = <Uri>[];

    await openFeed(tester, FixtureTwitterClient({}, requestedUris: sent));

    expect(find.byType(TweetConversation), findsWidgets, reason: 'The stored tweets should show without waiting for X');
    expect(sent.map(_sentCursor), contains(null), reason: 'The feed should reload its first page from X');
  });

  testWidgets('Should load the page after the stored ones at the bottom of the feed', (tester) async {
    await _storePage(tester, 'stored');
    final sent = <Uri>[];
    await openFeed(tester, FixtureTwitterClient({}, requestedUris: sent));

    await tester.fling(find.byType(TweetConversation).first, const Offset(0, -20000), 5000);
    await settleFeed(tester);

    expect(sent.map(_sentCursor), contains('stored'),
        reason: 'The stored tweets are in the list that loads the next pages, from where they end');
  });
}
