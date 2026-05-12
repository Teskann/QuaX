import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/client/client.dart';

/// Persists per-group feed state across navigator pop/push so that re-opening
/// the same pushed group route restores the loaded tweets and scroll offset.
///
/// Keys are caller-defined (`SubscriptionGroupFeed` passes the groupId for the
/// pushed-route case and skips the cache entirely for home-tab usages, so
/// home-tab and pushed-route feeds for the same group never share state).
///
/// Entries are cleared on subscription/group reload (wired in `main.dart`).
class FeedSessionCache {
  final Map<String, PagingController<String?, TweetChain>> _controllers = {};
  final Map<String, double> _offsets = {};

  PagingController<String?, TweetChain> getOrCreateController(String key) {
    return _controllers.putIfAbsent(
        key, () => PagingController<String?, TweetChain>(firstPageKey: null));
  }

  void saveOffset(String key, double offset) {
    _offsets[key] = offset;
  }

  double? readOffset(String key) => _offsets[key];

  // Drop references without disposing: a currently-mounted feed state may
  // still hold a reference and will remove its page-request listener in its
  // own dispose(). The old controller becomes garbage once the body remounts
  // via the shell's KeyedSubtree onto the freshly-cached controller.
  void invalidateAll() {
    _controllers.clear();
    _offsets.clear();
  }
}
