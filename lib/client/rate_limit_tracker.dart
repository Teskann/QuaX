/// In-memory, per-endpoint rate-limit memory.
///
/// X rate limits are per-endpoint, not per-account-globally: an account can be
/// `429` on `/SearchTimeline` while still serving `/TweetDetail`. We therefore
/// remember the reset time keyed by (account, endpoint). State is intentionally
/// not persisted — 429 windows are short (~15 min), so a restart simply forgets
/// them.
class RateLimitTracker {
  static final Map<String, Map<String, DateTime>> _resetByAccountEndpoint = {};

  static bool isLimited(String accountId, String endpoint, DateTime now) {
    final reset = _resetByAccountEndpoint[accountId]?[endpoint];
    return reset != null && reset.isAfter(now);
  }

  static void flag(String accountId, String endpoint, DateTime resetAt) {
    (_resetByAccountEndpoint[accountId] ??= {})[endpoint] = resetAt;
  }

  static void clear(String accountId, String endpoint) {
    _resetByAccountEndpoint[accountId]?.remove(endpoint);
  }
}
