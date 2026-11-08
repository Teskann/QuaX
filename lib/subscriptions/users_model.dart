import 'dart:ui';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/refreshed_profiles.dart';
import 'package:quax/user.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/subscription_order.dart';
import 'package:quax/subscriptions/subscription_order_store.dart';
import 'package:sqflite/sqflite.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';

class SubscriptionsModel extends Store<List<Subscription>> {
  static final log = Logger('SubscriptionsModel');

  final BasePrefService prefs;
  final GroupsModel groupModel;
  final Map<String, VoidCallback> _onSubscriptionsReloaded = {};

  SubscriptionsModel(this.prefs, this.groupModel) : super([]);

  void addReloadListener(String key, VoidCallback callback) {
    _onSubscriptionsReloaded[key] = callback;
  }

  void removeReloadListener(String key) {
    _onSubscriptionsReloaded.remove(key);
  }

  late final SubscriptionOrderStore order = SubscriptionOrderStore(prefs);

  Future<void> reloadSubscriptions() async {
    log.info('Listing subscriptions');

    await execute(() async {
      final database = await Repository.readOnly();
      final subscriptions = [
        for (final kind in SubscriptionKind.values) ...(await database.query(kind.table)).map(kind.fromRow),
      ];
      await order.reload(subscriptions);
      return order.state.apply(subscriptions);
    });
    for (final callback in _onSubscriptionsReloaded.values) {
      callback();
    }
  }

  Future<void> _showAndStoreOrder(SubscriptionOrder newOrder) async {
    update(newOrder.apply(state));
    await order.save(newOrder);
  }

  /// Switches to the next sort. The first custom order starts from the order shown.
  Future<void> showNextSort() {
    final current = order.state;
    final next = current.sort.next;
    final isFirstCustomOrder = next == SubscriptionSort.custom && current.customKeys.isEmpty;
    return _showAndStoreOrder(
        current.copyWith(sort: next, customKeys: isFirstCustomOrder ? state.map(subscriptionKey).toList() : null));
  }

  Future<void> reverseOrder() => _showAndStoreOrder(order.state.copyWith(ascending: !order.state.ascending));

  Future<void> moveSubscription(List<Subscription> visible, int oldIndex, int newIndex) =>
      _showAndStoreOrder(order.state.copyWith(
          customKeys: reorderedKeys(
              state.map(subscriptionKey).toList(), visible.map(subscriptionKey).toList(), oldIndex, newIndex)));

  Future<void> subscribe(Subscription subscription) async {
    final database = await Repository.writable();
    // Left out, so that the database dates the subscription to now
    final row = subscription.toMap()..remove('created_at');
    await database.insert(SubscriptionKind.of(subscription).table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
    await reloadSubscriptions();
  }

  /// Returns what [resubscribe] needs to undo it.
  Future<RemovedSubscriptions> unsubscribe(List<Subscription> subscriptions) async {
    final database = await Repository.writable();
    final refs = subscriptions.map(SubscriptionRef.of).toSet();
    final memberships = (await database.query(tableSubscriptionGroupMember))
        .map(SubscriptionGroupMember.fromMap)
        .where((m) => refsOf([m]).any(refs.contains))
        .toList();

    final batch = database.batch();
    for (final ref in refs) {
      batch.delete(ref.kind.table, where: 'id = ?', whereArgs: [ref.id]);
      batch.delete(tableSubscriptionGroupMember, where: 'kind = ? AND profile_id = ?', whereArgs: [ref.kind.name, ref.id]);
    }
    await batch.commit(noResult: true);

    await _reloadAfterMembershipChanges();
    return RemovedSubscriptions(subscriptions, memberships);
  }

  Future<void> resubscribe(RemovedSubscriptions removed) async {
    final database = await Repository.writable();
    final batch = database.batch();
    for (final subscription in removed.subscriptions) {
      batch.insert(SubscriptionKind.of(subscription).table, subscription.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (final membership in removed.memberships) {
      batch.insert(tableSubscriptionGroupMember, membership.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    await _reloadAfterMembershipChanges();
  }

  /// The feeds reload once, with the subscriptions.
  Future<void> _reloadAfterMembershipChanges() async {
    await groupModel.reloadGroups(notifyFeeds: false);
    await reloadSubscriptions();
  }

  Future<void> setShownInMainFeed(Iterable<Subscription> subscriptions, {required bool shown}) async {
    final batch = (await Repository.writable()).batch();
    for (final subscription in subscriptions.where((s) => SubscriptionKind.of(s).canHideFromMainFeed)) {
      batch.update(SubscriptionKind.of(subscription).table, {'in_feed': shown ? 1 : 0},
          where: 'id = ?', whereArgs: [subscription.id]);
    }
    await batch.commit(noResult: true);
    await reloadSubscriptions();
  }

  /// Saves the new name and picture of the subscriptions among [users], fresh from X
  Future<void> refreshSubscriptions(Iterable<UserWithExtra> users) async {
    final refreshed = refreshedSubscriptions(state, users);
    if (refreshed.isEmpty) {
      return;
    }
    log.info('Refreshing ${refreshed.length} subscriptions');

    final database = await Repository.writable();
    final batch = database.batch();
    for (final subscription in refreshed.values) {
      batch.update(tableSubscription,
          {'name': subscription.name, 'profile_image_url_https': subscription.profileImageUrlHttps},
          where: 'id = ?', whereArgs: [subscription.id]);
    }
    await batch.commit(noResult: true);

    // Not reloadSubscriptions(): its listeners would drop the feeds kept in memory
    update(state.map((subscription) => refreshed[subscription.id] ?? subscription).toList());
  }
}

class RemovedSubscriptions {
  final List<Subscription> subscriptions;
  final List<SubscriptionGroupMember> memberships;

  const RemovedSubscriptions(this.subscriptions, this.memberships);
}
