import 'package:quax/client/client.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';

/// The posts of a timeline, such as the one of a community or a list, loaded page by page.
class TimelinePagination {
  final TweetFeedController feed = TweetFeedController();
  final Future<TweetStatus> Function(String? cursor) _load;

  TimelinePagination(this._load);

  Future<TweetPageResult> loadPage(String? cursor) async {
    final result = await _load(cursor);
    // X can send a post again on a later page, alone or inside a thread
    final shown = cursor == null
        ? const <String?>{}
        : feed.items.expand((chain) => chain.tweets).map((t) => t.idStr).toSet();
    final unseen = result.chains.where((chain) => !chain.tweets.every((tweet) => shown.contains(tweet.idStr)));
    return (chains: unseen.toList(), nextCursor: result.cursorBottom);
  }

  void dispose() => feed.dispose();
}
