import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/rate_limit_tracker.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);
  final resetAt = now.add(const Duration(minutes: 15));
  AccountEndpoint search(String accountId) => AccountEndpoint(accountId: accountId, endpoint: '/SearchTimeline');
  AccountEndpoint tweetDetail(String accountId) => AccountEndpoint(accountId: accountId, endpoint: '/TweetDetail');

  group('RateLimit.fromHeaders()', () {
    test('Should read the quota and reset time sent by X', () {
      final limit = RateLimit.fromHeaders({
        'x-rate-limit-limit': '50',
        'content-type': 'application/json',
        'x-rate-limit-remaining': '47',
        'x-rate-limit-reset': '1790865516',
      });

      expect(limit?.remaining, 47, reason: 'x-rate-limit-remaining is the number of requests left in the window');
      expect(limit?.resetAt, DateTime.fromMillisecondsSinceEpoch(1790865516 * 1000),
          reason: 'x-rate-limit-reset is in epoch seconds, not milliseconds');
    });

    test('Should return null when the headers are missing or malformed', () {
      expect(RateLimit.fromHeaders({'content-type': 'application/json'}), isNull,
          reason: 'Some responses carry no rate-limit headers, which should not be mistaken for an empty quota');
      expect(RateLimit.fromHeaders({'x-rate-limit-remaining': 'abc', 'x-rate-limit-reset': '1790865516'}), isNull,
          reason: 'The API is reverse-engineered, so a malformed header should be ignored rather than throw');
    });
  });

  group('RateLimitTracker.hasCredit()', () {
    test('Should give credit to an account with an unknown quota', () {
      expect(RateLimitTracker.hasCredit(search('untracked'), now), isTrue,
          reason: 'An account that never called this endpoint should be free to use');
    });

    test('Should refuse credit once the quota reached zero, until the reset', () {
      RateLimitTracker.record(search('spent'), RateLimit(0, resetAt));

      expect(RateLimitTracker.hasCredit(search('spent'), now), isFalse,
          reason: 'X said the quota is spent, so another request would only get a 429');
      final afterReset = resetAt.add(const Duration(minutes: 1));
      expect(RateLimitTracker.hasCredit(search('spent'), afterReset), isTrue,
          reason: 'X gives a full quota again after the reset time, so the account should come back on its own');
    });

    test('Should keep limits separate for each endpoint', () {
      RateLimitTracker.record(search('perEndpoint'), RateLimit(0, resetAt));

      expect(RateLimitTracker.hasCredit(tweetDetail('perEndpoint'), now), isTrue,
          reason: 'X limits each endpoint on its own, so a spent search quota should leave the same '
              'account free to open a tweet');
    });
  });

  group('RateLimitTracker.consume()', () {
    test('Should count down one credit per request sent', () {
      RateLimitTracker.record(search('counted'), RateLimit(2, resetAt));
      RateLimitTracker.consume(search('counted'), now);
      RateLimitTracker.consume(search('counted'), now);

      expect(RateLimitTracker.hasCredit(search('counted'), now), isFalse,
          reason: 'Requests sent in parallel are not answered yet, so they should be counted locally. '
              'Otherwise a batch would send more requests than the quota allows');
    });
  });

  group('RateLimitTracker.record()', () {
    test('Should not give back credits counted locally when an older answer comes in', () {
      RateLimitTracker.record(search('outOfOrder'), RateLimit(3, resetAt));
      RateLimitTracker.consume(search('outOfOrder'), now);
      RateLimitTracker.record(search('outOfOrder'), RateLimit(3, resetAt));

      expect(RateLimitTracker.of(search('outOfOrder'), now)?.remaining, 2,
          reason: 'Within one window the quota only goes down, so a higher count comes from a request '
              'answered before the ones still in flight');
    });

    test('Should take the new count when a new window starts', () {
      RateLimitTracker.record(search('newWindow'), RateLimit(0, resetAt));
      final nextWindow = RateLimit(49, resetAt.add(const Duration(minutes: 15)));
      RateLimitTracker.record(search('newWindow'), nextWindow);

      expect(RateLimitTracker.of(search('newWindow'), now)?.remaining, 49,
          reason: 'A later reset time means X opened a new window with a full quota');
    });
  });
}
