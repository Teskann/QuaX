import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_order.dart';

/// The order the subscriptions show in, kept in the preferences.
class SubscriptionOrderStore extends Store<SubscriptionOrder> {
  final BasePrefService prefs;

  SubscriptionOrderStore(this.prefs) : super(const SubscriptionOrder(sort: SubscriptionSort.name, ascending: true));

  /// Reads the order again, as a restored backup replaces the preferences. Older versions stored the custom order
  /// as screen names: [subscriptions] turn it into the current one.
  Future<void> reload(List<Subscription> subscriptions) async {
    final stored = SubscriptionOrder(
      sort: SubscriptionSort.fromPrefValue(prefs.get(optionSubscriptionOrderByField)),
      ascending: prefs.get(optionSubscriptionOrderByAscending),
      customKeys: decodeCustomOrder(prefs.get(optionSubscriptionOrderCustomKeys)),
    );
    final String legacy = prefs.get(optionSubscriptionOrderCustom) ?? '';
    if (legacy.isEmpty) {
      update(stored);
      return;
    }
    await save(
      stored.copyWith(sort: SubscriptionSort.custom, customKeys: keysOfLegacyCustomOrder(legacy, subscriptions)),
    );
    await prefs.set(optionSubscriptionOrderCustom, '');
  }

  Future<void> save(SubscriptionOrder order) async {
    update(order);
    await prefs.set(optionSubscriptionOrderByField, order.sort.prefValue);
    await prefs.set(optionSubscriptionOrderByAscending, order.ascending);
    await prefs.set(optionSubscriptionOrderCustomKeys, encodeCustomOrder(order.customKeys));
  }
}
