import 'dart:async';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:logging/logging.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:sqflite/sqflite.dart';

/// Saves subscriptions and tells the app they changed.
class SubscriptionSaver {
  final ImportDataModel importModel;
  final GroupsModel groupsModel;
  final SubscriptionsModel subscriptionsModel;

  const SubscriptionSaver(this.importModel, this.groupsModel, this.subscriptionsModel);

  Future<void> add(List<UserSubscription> subscriptions) =>
      importModel.importData({tableSubscription: subscriptions});

  Future<void> reload() async {
    await groupsModel.reloadGroups();
    await subscriptionsModel.reloadSubscriptions();
  }
}

/// Where the followed accounts wait to be imported, the first in line first.
abstract interface class SubscriptionImportStore {
  Future<void> enqueue(List<UserSubscription> subscriptions);

  Future<List<UserSubscription>> next(int count);

  Future<void> remove(List<String> ids);

  Future<int> count();
}

class SqliteSubscriptionImportStore implements SubscriptionImportStore {
  const SqliteSubscriptionImportStore();

  @override
  Future<void> enqueue(List<UserSubscription> subscriptions) async {
    final database = await Repository.writable();
    final last = Sqflite.firstIntValue(
        await database.rawQuery('SELECT MAX(position) FROM $tableSubscriptionImportQueue'));
    final batch = database.batch();
    for (final (index, subscription) in subscriptions.indexed) {
      batch.insert(tableSubscriptionImportQueue, _toRow(subscription, (last ?? -1) + 1 + index),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<UserSubscription>> next(int count) async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableSubscriptionImportQueue, orderBy: 'position ASC', limit: count);
    return rows.map((row) => UserSubscription.fromMap({...row, 'in_feed': 1})).toList();
  }

  @override
  Future<void> remove(List<String> ids) async {
    final database = await Repository.writable();
    final batch = database.batch();
    for (final id in ids) {
      batch.delete(tableSubscriptionImportQueue, where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<int> count() async {
    final database = await Repository.readOnly();
    return Sqflite.firstIntValue(await database.rawQuery('SELECT COUNT(*) FROM $tableSubscriptionImportQueue')) ?? 0;
  }

  Map<String, Object?> _toRow(UserSubscription subscription, int position) =>
      {...subscription.toMap()..remove('in_feed'), 'position': position};
}

typedef PeriodicTimerFactory = Timer Function(Duration interval, void Function(Timer timer) onTick);

/// Imports the accounts waiting in the queue [smartImportBatch] at a time, every [smartImportInterval] while the app
/// runs. The state is how many accounts are still waiting.
class SubscriptionImportQueueModel extends Store<int> {
  static final log = Logger('SubscriptionImportQueueModel');

  final SubscriptionImportStore store;
  final SubscriptionSaver saver;
  final PeriodicTimerFactory createTimer;
  Timer? _timer;
  bool _importing = false;

  SubscriptionImportQueueModel(this.store, this.saver, {this.createTimer = Timer.periodic}) : super(0);

  bool get isRunning => _timer != null;

  /// Starts draining the queue, if there is anything in it. Call it at launch and once accounts were queued.
  Future<void> start() async {
    update(await store.count());
    if (state > 0 && _timer == null) {
      _timer = createTimer(smartImportInterval, (_) => _tick());
    }
  }

  /// Queues [subscriptions] behind the ones already waiting, and starts importing them.
  Future<void> enqueue(List<UserSubscription> subscriptions) async {
    await store.enqueue(subscriptions);
    await start();
  }

  Future<void> _tick() async {
    if (_importing) return;
    _importing = true;
    try {
      await _importNext();
    } catch (e, stackTrace) {
      log.warning('Unable to import the next subscriptions, will retry', e, stackTrace);
    } finally {
      _importing = false;
    }
  }

  Future<void> _importNext() async {
    final batch = await store.next(smartImportBatch);
    if (batch.isNotEmpty) {
      await saver.add(batch);
      await store.remove(batch.map((e) => e.id).toList());
    }
    update(await store.count());
    if (state == 0) _stop();
    if (batch.isNotEmpty) await saver.reload();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future destroy() async {
    _stop();
    return super.destroy();
  }
}
