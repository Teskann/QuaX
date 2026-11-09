import 'package:crypto/crypto.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/search_query.dart';
import 'package:quax/utils/iterables.dart';

/// A part of a feed. One request to X loads it, and it has its own cache.
sealed class FeedChunk {
  /// The key of its cache.
  String get hash;

  /// The number of subscriptions it loads.
  int get subscriptionCount;
}

/// A chunk loaded by one X search. The search keeps or leaves out replies and reposts, as the feed asks.
sealed class SearchFeedChunk extends FeedChunk {
  final bool includeReplies;
  final bool includeRetweets;

  SearchFeedChunk({required this.includeReplies, required this.includeRetweets});

  String get query;

  /// The same query finds the same posts, so it is the key of the cache.
  @override
  String get hash => _sha1(query);
}

/// Accounts and saved searches, searched together.
class SharedSearchFeedChunk extends SearchFeedChunk {
  final List<SearchableSubscription> subscriptions;

  SharedSearchFeedChunk(this.subscriptions, {required super.includeReplies, required super.includeRetweets});

  @override
  String get query =>
      buildFeedSearchQuery(subscriptions, includeReplies: includeReplies, includeRetweets: includeRetweets);

  @override
  int get subscriptionCount => subscriptions.length;
}

/// The latest posts of one community. X search cannot find them.
/// They are never replies or reposts, so the filters of the feed do not apply.
class CommunityFeedChunk extends FeedChunk {
  final CommunitySubscription community;

  CommunityFeedChunk(this.community);

  @override
  String get hash => _sha1('community:${community.id}');

  @override
  int get subscriptionCount => 1;
}

/// The posts of the members of one list.
/// X accepts list: only at the top of a search, not in brackets nor in an OR, so each list has a search of its own.
class ListFeedChunk extends SearchFeedChunk {
  final ListSubscription list;

  ListFeedChunk(this.list, {required super.includeReplies, required super.includeRetweets});

  @override
  String get query => buildListSearchQuery(list.id, includeReplies: includeReplies, includeRetweets: includeRetweets);

  @override
  int get subscriptionCount => 1;
}

String _sha1(String text) => sha1.convert(text.codeUnits).toString();

/// Splits a feed into chunks. The oldest subscriptions come first, so a new one only changes the last chunk.
List<FeedChunk> feedChunksOf(SubscriptionGroupGet group) {
  final subscriptions = group.feedSubscriptions.sorted((a, b) => a.createdAt.compareTo(b.createdAt)).toList();
  final searchable = subscriptions.whereType<SearchableSubscription>().toList();
  final packed = packFeedChunks(
    searchable,
    includeReplies: group.includeReplies,
    includeRetweets: group.includeRetweets,
  );
  return [
    ...packed.map(
      (chunk) =>
          SharedSearchFeedChunk(chunk, includeReplies: group.includeReplies, includeRetweets: group.includeRetweets),
    ),
    ...subscriptions.map((subscription) => _ownChunk(subscription, group)).nonNulls,
  ];
}

/// The chunk of a subscription that cannot share an X search. Null for the others.
FeedChunk? _ownChunk(Subscription subscription, SubscriptionGroupGet group) => switch (subscription) {
  SearchableSubscription() => null,
  CommunitySubscription() => CommunityFeedChunk(subscription),
  ListSubscription() => ListFeedChunk(
    subscription,
    includeReplies: group.includeReplies,
    includeRetweets: group.includeRetweets,
  ),
};
