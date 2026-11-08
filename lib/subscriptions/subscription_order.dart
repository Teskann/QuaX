import 'dart:convert';

import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_kind.dart';

enum SubscriptionSort {
  name('name'),
  screenName('screen_name'),
  createdAt('created_at'),
  custom('custom');

  const SubscriptionSort(this.prefValue);

  final String prefValue;

  static SubscriptionSort fromPrefValue(String? prefValue) =>
      values.firstWhere((sort) => sort.prefValue == prefValue, orElse: () => SubscriptionSort.name);

  SubscriptionSort get next => values[(index + 1) % values.length];
}

class SubscriptionOrder {
  final SubscriptionSort sort;
  final bool ascending;
  final List<String> customKeys;

  const SubscriptionOrder({required this.sort, required this.ascending, this.customKeys = const []});

  SubscriptionOrder copyWith({SubscriptionSort? sort, bool? ascending, List<String>? customKeys}) => SubscriptionOrder(
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
    customKeys: customKeys ?? this.customKeys,
  );

  List<Subscription> apply(Iterable<Subscription> subscriptions) {
    if (sort == SubscriptionSort.custom) {
      return _inCustomOrder(subscriptions.toList()..sort(compareNames));
    }
    final sorted = subscriptions.toList()..sort(_compare);
    return ascending ? sorted : sorted.reversed.toList();
  }

  int _compare(Subscription a, Subscription b) => switch (sort) {
    SubscriptionSort.screenName => a.screenName.toLowerCase().compareTo(b.screenName.toLowerCase()),
    SubscriptionSort.createdAt => a.createdAt.compareTo(b.createdAt),
    SubscriptionSort.name || SubscriptionSort.custom => compareNames(a, b),
  };

  List<Subscription> _inCustomOrder(List<Subscription> byName) {
    final position = {for (final (index, key) in customKeys.indexed) key: index};
    // Subscriptions added since the custom order was set go last
    final ranked =
        byName.indexed
            .map(
              (entry) =>
                  (rank: position[subscriptionKey(entry.$2)] ?? customKeys.length + entry.$1, subscription: entry.$2),
            )
            .toList()
          ..sort((a, b) => a.rank.compareTo(b.rank));
    return ranked.map((entry) => entry.subscription).toList();
  }
}

int compareNames(Subscription a, Subscription b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());

String encodeCustomOrder(List<String> keys) => jsonEncode(keys);

List<String> decodeCustomOrder(String? stored) {
  try {
    return List<String>.from(jsonDecode(stored ?? '[]') as List);
  } catch (_) {
    return const [];
  }
}

/// Older versions stored the custom order as screen names.
List<String> keysOfLegacyCustomOrder(String legacy, Iterable<Subscription> subscriptions) => legacy
    .split(',')
    .map((screenName) => subscriptions.where((s) => s.screenName == screenName).firstOrNull)
    .nonNulls
    .map(subscriptionKey)
    .toList();

/// Moves a key of the shown [visible] ones, and returns the new order of [all] of them.
List<String> reorderedKeys(List<String> all, List<String> visible, int oldIndex, int newIndex) {
  final moved = visible[oldIndex];
  final shown = [...visible]..removeAt(oldIndex);
  final rest = all.where((key) => key != moved).toList();
  final insertAt = newIndex < shown.length ? rest.indexOf(shown[newIndex]) : rest.indexOf(shown.last) + 1;
  return [...rest]..insert(insertAt, moved);
}
