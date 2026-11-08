import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/feed_chunk.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_chunk_page.dart';
import 'package:sqflite/sqflite.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../subscriptions/fixtures.dart';
import 'open_feed.dart';

final _chunk = flutterDevChunk;

Fixture _recorded() => fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true);

TweetStatus _page(String cursor) =>
    TweetStatus(chains: Twitter.parseSearchTimeline(_recorded().body).chains, cursorBottom: cursor, cursorTop: null);

String? _sentCursor(Uri uri) => jsonDecode(uri.queryParameters['variables']!)['cursor'] as String?;

void main() {
  late Database repository;

  useFreshDatabase();

  setUp(() async => repository = await Repository.writable());

  Future<List<Uri>> loadNextPage(Fixture answer) async {
    final sent = <Uri>[];
    Twitter.client = FixtureTwitterClient({'SearchTimeline': answer}, requestedUris: sent);
    await loadChunkPage(repository, _chunk, firstPage: false);
    return sent;
  }

  test('Should go on from the cursor of the last page stored for the chunk', () async {
    await storeChunkPage(repository, _chunk.hash, _page('page-1'), firstPage: true);
    await storeChunkPage(repository, _chunk.hash, _page('page-2'), firstPage: false);

    final sent = await loadNextPage(_recorded());

    expect(_sentCursor(sent.single), 'page-2', reason: 'The next page of a chunk starts where its last page ended');
  });

  test('Should not search again a chunk whose last page was empty', () async {
    await storeChunkPage(repository, _chunk.hash, _page('page-1'), firstPage: true);
    await storeChunkPage(repository, _chunk.hash, TweetStatus(chains: [], cursorBottom: 'empty', cursorTop: null),
        firstPage: false);

    final sent = await loadNextPage(_recorded());

    expect(sent, isEmpty, reason: 'The chunk has nothing more, so searching it again would only use up the rate limit');
  });

  test('Should not search the next page of a chunk that never had tweets', () async {
    final sent = await loadNextPage(_recorded());

    expect(sent, isEmpty, reason: 'Without a cursor, the search would start over from the newest tweets');
  });

  test('Should keep the stored pages and their cursor when X cannot be reached', () async {
    await storeChunkPage(repository, _chunk.hash, _page('page-1'), firstPage: true);
    Twitter.client = FixtureTwitterClient({});

    final page = await loadChunkPage(repository, _chunk, firstPage: true);

    expect(page.failed, isTrue, reason: 'X did not answer');
    expect(page.tweets, isNotEmpty, reason: 'The stored tweets should be shown while X cannot be reached');
    expect(page.cursor, 'page-1', reason: 'The next page should still follow the stored ones');
  });

  test('Should replace the stored pages of the chunk with the first page X sent', () async {
    await storeChunkPage(repository, _chunk.hash, _page('page-1'), firstPage: true);
    await storeChunkPage(repository, _chunk.hash, _page('page-2'), firstPage: false);
    Twitter.client = FixtureTwitterClient({'SearchTimeline': _recorded()});

    final page = await loadChunkPage(repository, _chunk, firstPage: true);

    final stored = await repository.query(tableFeedGroupChunk, where: 'hash = ?', whereArgs: [_chunk.hash]);
    expect(stored, hasLength(1), reason: 'A fresh first page replaces every page stored before');
    expect(page.cursor, stored.single['cursor_bottom'], reason: 'The next page should follow the fresh first page');
  });

  group('A community', () {
    final communityChunk = CommunityFeedChunk(followedCommunity('Flutter'));

    Future<List<Uri>> load({required bool firstPage}) async {
      final sent = <Uri>[];
      Twitter.client = FixtureTwitterClient({
        'CommunityTweetsTimeline': fixture('CommunityTweetsTimeline', 'vars-a65415', unstable: true),
      }, requestedUris: sent);
      await loadChunkPage(repository, communityChunk, firstPage: firstPage);
      return sent;
    }

    Map<String, dynamic> variablesOf(Uri uri) => jsonDecode(uri.queryParameters['variables']!);

    test('Should load the latest posts of a community rather than search it', () async {
      final sent = await load(firstPage: true);

      expect(
        sent.single.path,
        endsWith('/CommunityTweetsTimeline'),
        reason: 'X cannot search the posts of a community',
      );
      expect(
        variablesOf(sent.single)['communityId'],
        communityChunk.community.id,
        reason: 'The timeline should be the one of the community followed',
      );
      expect(
        variablesOf(sent.single)['rankingMode'],
        'Recency',
        reason: 'A feed shows the latest posts, not the top ones',
      );
      expect(
        await readStoredChains(repository, communityChunk.hash),
        isNotEmpty,
        reason: 'The posts of the community should fill the chunk',
      );
    });

    test('Should go on with the next posts of the community', () async {
      await load(firstPage: true);
      final stored = await readChunkCursor(repository, communityChunk.hash);

      final sent = await load(firstPage: false);

      expect(
        sent.single.path,
        endsWith('/CommunityTweetsTimeline'),
        reason: 'The next page comes from the community too',
      );
      expect(variablesOf(sent.single)['cursor'], stored, reason: 'The next page starts where the stored one ended');
    });
  });
}
