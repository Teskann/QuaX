import 'package:quax/tweet/paginated_tweet_list.dart';

/// Persists per-group feed state across navigator pop/push so that re-opening
/// the same pushed group route restores the loaded tweets and scroll offset.
///
/// Keys are caller-defined (`SubscriptionGroupFeed` passes the groupId for the
/// pushed-route case and skips the cache entirely for home-tab usages, so
/// home-tab and pushed-route feeds for the same group never share state).
///
/// Entries are cleared on subscription/group reload (wired in `main.dart`).
class FeedSessionCache {
  final Map<String, TweetFeedController> _controllers = {};
  final Map<String, double> _offsets = {};

  TweetFeedController getOrCreateController(String key) {
    return _controllers.putIfAbsent(key, () => TweetFeedController());
  }

  void saveOffset(String key, double offset) {
    _offsets[key] = offset;
  }

  double? readOffset(String key) => _offsets[key];

  // Drop references without disposing: a currently-mounted feed state may
  // still hold a reference and will detach its own listener in its dispose().
  // The old controller becomes garbage once the body remounts via the shell's
  // KeyedSubtree onto the freshly-cached controller.
  void invalidateAll() {
    _controllers.clear();
    _offsets.clear();
  }
}
