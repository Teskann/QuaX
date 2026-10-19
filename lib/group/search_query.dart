import 'package:quax/database/entities.dart';

/// The longest query X reads for one search.
const maxQueryLength = 512;

String _feedSearchQuery(
  List<Subscription> subscriptions, {
  required bool includeReplies,
  required bool includeRetweets,
}) {
  final subscriptionsQuery = subscriptions.map((subscription) => subscription.searchTerm).join(' OR ');

  return [
    if (subscriptionsQuery.isNotEmpty) '($subscriptionsQuery)',
    if (!includeReplies) '-filter:replies',
    includeRetweets ? 'include:nativeretweets' : '-filter:retweets',
  ].join(' ');
}

/// Builds the X search query used to load one chunk of a feed or group.
String buildFeedSearchQuery(
  List<Subscription> subscriptions, {
  required bool includeReplies,
  required bool includeRetweets,
}) {
  final query = _feedSearchQuery(subscriptions, includeReplies: includeReplies, includeRetweets: includeRetweets);

  assert(subscriptions.length <= 1 || query.length <= maxQueryLength,
      'A chunk of several subscriptions should be packed to fit one query');

  return query;
}

/// Splits [subscriptions] into the fewest chunks whose queries each fit [maxQueryLength].
/// Walks the given order, so appending a subscription only disturbs the last chunk. A subscription
/// too long to fit a query on its own gets a chunk of its own and is left to fail against X, rather
/// than being silently dropped or truncated.
List<List<Subscription>> packFeedChunks(
  List<Subscription> subscriptions, {
  required bool includeReplies,
  required bool includeRetweets,
}) {
  int queryLengthOf(List<Subscription> chunk) =>
      _feedSearchQuery(chunk, includeReplies: includeReplies, includeRetweets: includeRetweets).length;

  final chunks = <List<Subscription>>[];
  for (final subscription in subscriptions) {
    if (chunks.isNotEmpty && queryLengthOf([...chunks.last, subscription]) <= maxQueryLength) {
      chunks.last.add(subscription);
    } else {
      chunks.add([subscription]);
    }
  }

  return chunks;
}
