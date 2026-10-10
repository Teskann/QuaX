import 'package:quax/client/client.dart';

/// [follows] ordered by the newest post [latest] holds for each of them, newest first. A repost counts for the account
/// that reposted. Accounts with no post in [latest] come last, in their original order, as do ties.
List<T> rankByRecentActivity<T>(List<T> follows, String Function(T) idOf, Iterable<TweetChain> latest) {
  final newest = _newestPostTimes(latest);
  final indexed = follows.indexed.toList();
  final seen = indexed.where((e) => newest.containsKey(idOf(e.$2))).toList()
    ..sort((a, b) {
      final byTime = newest[idOf(b.$2)]!.compareTo(newest[idOf(a.$2)]!);
      return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
    });
  final unseen = indexed.where((e) => !newest.containsKey(idOf(e.$2)));
  return [...seen, ...unseen].map((e) => e.$2).toList();
}

Map<String, DateTime> _newestPostTimes(Iterable<TweetChain> chains) {
  final newest = <String, DateTime>{};
  for (final tweet in chains.expand((chain) => chain.tweets)) {
    final id = tweet.user?.idStr;
    final time = tweet.createdAt;
    if (id != null && time != null && (newest[id]?.isBefore(time) ?? true)) {
      newest[id] = time;
    }
  }
  return newest;
}
