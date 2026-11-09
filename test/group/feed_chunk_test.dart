import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/feed_chunk.dart';

import '../subscriptions/fixtures.dart';

SubscriptionGroupGet _group(
  List<Subscription> subscriptions, {
  bool includeReplies = true,
  bool includeRetweets = true,
}) => SubscriptionGroupGet(
  id: 'tech',
  name: 'Tech',
  icon: '',
  subscriptions: subscriptions,
  includeReplies: includeReplies,
  includeRetweets: includeRetweets,
);

void main() {
  test('Should load each community on its own, apart from the accounts and searches searched together', () {
    final chunks = feedChunksOf(_group([account('alice'), followedCommunity('Flutter'), savedSearch('dart')]));

    expect(chunks.whereType<SharedSearchFeedChunk>().single.subscriptions, [
      account('alice'),
      savedSearch('dart'),
    ], reason: 'The accounts and the searches should share one X search');
    expect(
      chunks.whereType<CommunityFeedChunk>().single.community,
      followedCommunity('Flutter'),
      reason: 'X cannot search a community, so it should load its own timeline',
    );
  });

  test('Should search each list on its own, apart from the accounts searched together', () {
    final chunks = feedChunksOf(_group([account('alice'), followedList('Dart')]));

    expect(chunks.whereType<SharedSearchFeedChunk>().single.subscriptions, [
      account('alice'),
    ], reason: 'The accounts should still be searched');
    expect(
      chunks.whereType<ListFeedChunk>().single.list,
      followedList('Dart'),
      reason: 'X accepts list: only at the top of a search, so each list should have a search of its own',
    );
  });

  test('Should keep the cache of a community when the filters of the group change', () {
    String communityHash({required bool includeReplies}) =>
        feedChunksOf(_group([followedCommunity('Flutter')], includeReplies: includeReplies)).single.hash;

    expect(
      communityHash(includeReplies: true),
      communityHash(includeReplies: false),
      reason: 'The filters do not apply to a community, so its stored posts are still valid',
    );
  });

  test('Should start the cache of a list over when the filters of the group change', () {
    String listHash({required bool includeRetweets}) =>
        feedChunksOf(_group([followedList('Dart')], includeRetweets: includeRetweets)).single.hash;

    expect(
      listHash(includeRetweets: true),
      isNot(listHash(includeRetweets: false)),
      reason: 'The search of the list changes, so its stored posts may not fit the filters',
    );
  });

  test('Should not share the cache of a saved search of the same list', () {
    final saved = feedChunksOf(_group([savedSearch('list:123')])).single.hash;
    final list = ListSubscription(id: '123', name: 'Dart', bannerUrl: null, createdAt: DateTime(2026));

    expect(feedChunksOf(_group([list])).single.hash, isNot(saved),
        reason: 'They load different searches, so each one needs its own stored posts');
  });
}
