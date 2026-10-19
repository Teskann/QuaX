/// Quota left on one endpoint for one account, as reported by X in the
/// `x-rate-limit-remaining` / `x-rate-limit-reset` headers.
class RateLimit {
  final int remaining;
  final DateTime resetAt;

  const RateLimit(this.remaining, this.resetAt);

  static RateLimit? fromHeaders(Map<String, String> headers) {
    final remaining = int.tryParse(headers['x-rate-limit-remaining'] ?? '');
    final reset = int.tryParse(headers['x-rate-limit-reset'] ?? ''); // epoch seconds
    if (remaining == null || reset == null) {
      return null;
    }
    return RateLimit(remaining, DateTime.fromMillisecondsSinceEpoch(reset * 1000));
  }
}

/// Identifies one rate limit: X counts the requests of each account on each
/// endpoint separately.
class AccountEndpoint {
  final String accountId;
  final String endpoint;

  const AccountEndpoint({required this.accountId, required this.endpoint});

  @override
  bool operator ==(Object other) =>
      other is AccountEndpoint && other.accountId == accountId && other.endpoint == endpoint;

  @override
  int get hashCode => Object.hash(accountId, endpoint);
}

/// In-memory, per-endpoint rate-limit memory.
///
/// X rate limits are per-endpoint, not per-account-globally: an account can be
/// `429` on `/SearchTimeline` while still serving `/TweetDetail`. We therefore
/// remember the quota keyed by [AccountEndpoint], and count down one credit
/// per request sent so parallel requests never exceed it. State is
/// intentionally not persisted — windows are short (~15 min).
class RateLimitTracker {
  static final Map<AccountEndpoint, RateLimit> _limits = {};

  static RateLimit? of(AccountEndpoint accountEndpoint, DateTime now) {
    final limit = _limits[accountEndpoint];
    return limit != null && limit.resetAt.isAfter(now) ? limit : null;
  }

  static bool hasCredit(AccountEndpoint accountEndpoint, DateTime now) =>
      (of(accountEndpoint, now)?.remaining ?? 1) > 0;

  static void consume(AccountEndpoint accountEndpoint, DateTime now) {
    final limit = of(accountEndpoint, now);
    if (limit != null) {
      _limits[accountEndpoint] = RateLimit(limit.remaining - 1, limit.resetAt);
    }
  }

  static void record(AccountEndpoint accountEndpoint, RateLimit limit) {
    final known = _limits[accountEndpoint];
    final sameWindow = known != null && known.resetAt == limit.resetAt;
    _limits[accountEndpoint] = sameWindow && known.remaining < limit.remaining ? known : limit;
  }
}
