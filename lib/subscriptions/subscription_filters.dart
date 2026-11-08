import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_kind.dart';

String normalizeQuery(String? query) => query?.trim().toLowerCase() ?? '';

bool matchesQuery(Subscription subscription, String query) =>
    query.isEmpty ||
    subscription.name.toLowerCase().contains(query) ||
    subscription.screenName.toLowerCase().contains(query);

/// [query] is trimmed and lower case.
List<Subscription> subscriptionsMatching(List<Subscription> all, String query) =>
    all.where((s) => matchesQuery(s, query)).toList();

/// The subscriptions matching [query], and those of them of the chosen [kind]. A null [kind] shows every kind.
({List<Subscription> matching, List<Subscription> shown}) filterSubscriptions(
  List<Subscription> all,
  String query,
  SubscriptionKind? kind,
) {
  final matching = subscriptionsMatching(all, query);
  return (matching: matching, shown: subscriptionsOfKind(matching, kind));
}

List<Subscription> subscriptionsOfKind(List<Subscription> subscriptions, SubscriptionKind? kind) =>
    subscriptions.where((s) => kind == null || SubscriptionKind.of(s) == kind).toList();

/// While searching, a group shows if its name matches or if it holds a matching subscription.
List<SubscriptionGroup> groupsMatchingSearch(
  List<SubscriptionGroup> groups,
  Map<String, Set<SubscriptionRef>> members,
  List<Subscription> matching,
  String query,
) {
  if (query.isEmpty) {
    return groups;
  }
  final refs = matching.map(SubscriptionRef.of).toSet();
  return groups
      .where((g) => g.name.toLowerCase().contains(query) || (members[g.id] ?? const {}).any(refs.contains))
      .toList();
}

/// A filter shows only for kinds with subscriptions, plus the one chosen.
List<SubscriptionKind> kindsToFilterBy(Iterable<Subscription> subscriptions, SubscriptionKind? chosen) {
  final present = countByKind(subscriptions).keys;
  return SubscriptionKind.values.where((kind) => kind == chosen || present.contains(kind)).toList();
}
