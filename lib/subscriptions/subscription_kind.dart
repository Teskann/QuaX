import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';

/// What a subscription follows: an account or a saved search.
enum SubscriptionKind {
  user(tableSubscription, UserSubscription.fromMap, canHideFromMainFeed: true),
  search(tableSearchSubscription, SearchSubscription.fromMap, canHideFromMainFeed: false);

  const SubscriptionKind(this.table, this.fromRow, {required this.canHideFromMainFeed});

  /// The SQLite table where the subscriptions of this kind are stored.
  final String table;

  /// Reads a row of [table].
  final Subscription Function(Map<String, Object?> row) fromRow;

  /// Whether the main feed can leave the subscriptions of this kind out.
  final bool canHideFromMainFeed;

  static SubscriptionKind of(Subscription subscription) => switch (subscription) {
    UserSubscription() => user,
    SearchSubscription() => search,
  };

  /// The kind stored under [name], such as in the group members table.
  static SubscriptionKind? named(String name) => values.where((kind) => kind.name == name).firstOrNull;
}

/// A subscription as groups and the custom order refer to it. Ids of different kinds may be equal.
final class SubscriptionRef {
  final SubscriptionKind kind;
  final String id;

  const SubscriptionRef(this.kind, this.id);

  SubscriptionRef.of(Subscription subscription) : this(SubscriptionKind.of(subscription), subscription.id);

  /// Such as `user:123`.
  String get key =>
      // The custom order stores these keys: renaming a kind would lose its subscriptions' place
      '${kind.name}:$id';

  @override
  bool operator ==(Object other) => other is SubscriptionRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => key;
}

String subscriptionKey(Subscription subscription) => SubscriptionRef.of(subscription).key;

/// Kinds without any subscription are left out.
Map<SubscriptionKind, int> countByKind(Iterable<Subscription> subscriptions) =>
    subscriptions.fold({}, (counts, s) => counts..update(SubscriptionKind.of(s), (n) => n + 1, ifAbsent: () => 1));
