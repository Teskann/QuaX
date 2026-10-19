import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/account_selector.dart';
import 'package:quax/client/rate_limit_tracker.dart';
import 'package:quax/database/entities.dart';

void main() {
  final now = DateTime(2026, 9, 4, 12);

  Account account(String id) => Account(id: id, authHeader: '{}', screenName: id);

  group('AccountSelector.pick()', () {
    test('Should prefer an account that is not rate limited on this endpoint', () {
      final selector = AccountSelector([account('limited'), account('healthy')],
          hasCredit: (a) => a.id != 'limited');

      expect(selector.pick(exclude: {})?.id, 'healthy',
          reason: 'Rate limits are per endpoint, and one account here is free of them, so that '
              'one should be chosen. Only one is healthy in each test because pick draws at '
              'random among the healthy accounts');
    });

    test('Should never return an account with no credit left', () {
      final selector = AccountSelector([account('limited')], hasCredit: (_) => false);

      expect(selector.pick(exclude: {}), isNull,
          reason: 'X said the quota is spent, so a request would only get a 429. It should not be sent');
    });

    test('Should not send more requests than the credits left, even in a parallel batch', () {
      final resetAt = now.add(const Duration(minutes: 15));
      AccountEndpoint batch(String accountId) => AccountEndpoint(accountId: accountId, endpoint: '/Batch');
      RateLimitTracker.record(batch('batchA'), RateLimit(5, resetAt));
      RateLimitTracker.record(batch('batchB'), RateLimit(5, resetAt));
      final selector = AccountSelector([account('batchA'), account('batchB')],
          hasCredit: (a) => RateLimitTracker.hasCredit(batch(a.id), now));

      // What fetch() does for each request of a batch, before any answer comes back
      var sent = 0;
      for (var i = 0; i < 15; i++) {
        final picked = selector.pick(exclude: {});
        if (picked != null) {
          RateLimitTracker.consume(batch(picked.id), now);
          sent++;
        }
      }

      expect(sent, 10,
          reason: 'Only 10 credits are left across both accounts, so only 10 of the 15 requests '
              'should be sent. The others would only get 429s');
    });

    test('Should never return an account that was already tried for this request', () {
      final selector = AccountSelector([account('a'), account('b')]);

      expect(selector.pick(exclude: {'a'})?.id, 'b',
          reason: 'Account a was already tried and failed, so it should not come back. Trying it '
              'again would waste a request and could loop on the same error');
      expect(selector.pick(exclude: {'a', 'b'}), isNull,
          reason: 'Null is what stops the retry loop, so once every account has been tried it '
              'should be returned. Anything else would loop forever');
    });

    test('Should return null when there is no account at all', () {
      expect(AccountSelector([]).pick(exclude: {}), isNull,
          reason: 'With no account there is nothing to choose, so null should come back. That is '
              'what tells the caller to fall back to a guest request');
    });
  });
}
