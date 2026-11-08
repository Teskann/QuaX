import 'package:flutter_test/flutter_test.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/subscription_order.dart';

import 'fixtures.dart';

void main() {
  test('Should put the subscriptions followed after the custom order was set at its end', () {
    final order = SubscriptionOrder(
      sort: SubscriptionSort.custom,
      ascending: true,
      customKeys: [subscriptionKey(account('zoe')), subscriptionKey(account('bob'))],
    );

    final names = order.apply([account('bob'), account('new'), account('zoe'), account('alice')]).map((s) => s.name);

    expect(names, [
      'zoe',
      'bob',
      'alice',
      'new',
    ], reason: 'The chosen order should stay as set, the subscriptions it does not know follow by name');
  });

  test('Should keep the hidden subscriptions in place when a filtered one is moved', () {
    final all = ['a', 'hidden', 'b', 'c'];

    expect(reorderedKeys(all, ['a', 'b', 'c'], 0, 2), [
      'hidden',
      'b',
      'c',
      'a',
    ], reason: 'Moving "a" after "c" among the shown ones should not move "hidden"');
    expect(reorderedKeys(all, ['a', 'b', 'c'], 2, 1), [
      'a',
      'hidden',
      'c',
      'b',
    ], reason: 'Moving "c" before "b" should put it right before "b", after "hidden"');
  });

  test('Should read the custom order stored by older versions', () {
    final subscriptions = [account('bob'), savedSearch('flutter'), account('zoe')];

    expect(keysOfLegacyCustomOrder('zoe,flutter,gone,bob', subscriptions), [
      'user:id-zoe',
      'search:flutter',
      'user:id-bob',
    ], reason: 'Screen names should become keys, and unfollowed ones should be dropped');
  });

  test('Should move a subscription to the last place', () {
    expect(reorderedKeys(['a', 'hidden', 'b'], ['a', 'b'], 0, 1), [
      'hidden',
      'b',
      'a',
    ], reason: 'Dropping "a" below the last row shown should put it right after that row');
  });

  test('Should read the sorts stored by this and older versions', () {
    final stored = {
      'name': SubscriptionSort.name,
      'screen_name': SubscriptionSort.screenName,
      'created_at': SubscriptionSort.createdAt,
      'custom': SubscriptionSort.custom,
    };

    expect(
      stored.keys.map(SubscriptionSort.fromPrefValue),
      stored.values,
      reason: 'Preferences and backups keep these values: changing one would lose the chosen sort',
    );
    expect(
      SubscriptionSort.fromPrefValue('unknown'),
      SubscriptionSort.name,
      reason: 'A value this version does not know should fall back to the default sort',
    );
  });
}
