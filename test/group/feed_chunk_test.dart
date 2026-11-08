import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/feed_chunk.dart';

import '../subscriptions/fixtures.dart';

SubscriptionGroupGet _group(List<Subscription> subscriptions, {bool includeReplies = true}) => SubscriptionGroupGet(
  id: 'tech',
  name: 'Tech',
  icon: '',
  subscriptions: subscriptions,
  includeReplies: includeReplies,
  includeRetweets: true,
);

void main() {
  test('Should load each community on its own, apart from the accounts and searches searched together', () {
    final chunks = feedChunksOf(_group([account('alice'), followedCommunity('Flutter'), savedSearch('dart')]));

    expect(chunks.whereType<SearchFeedChunk>().single.subscriptions, [
      account('alice'),
      savedSearch('dart'),
    ], reason: 'The accounts and the searches should share one X search');
    expect(
      chunks.whereType<CommunityFeedChunk>().single.community,
      followedCommunity('Flutter'),
      reason: 'X cannot search a community, so it should load its own timeline',
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
}
