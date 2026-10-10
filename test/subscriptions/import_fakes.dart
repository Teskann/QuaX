import 'dart:async';

import 'package:dart_twitter_api/twitter_api.dart' show User;
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_import_queue.dart';
import 'package:quax/user.dart';

/// The queue kept in memory, in the order of insertion.
class MemoryImportStore implements SubscriptionImportStore {
  final List<UserSubscription> queued = [];

  @override
  Future<void> enqueue(List<UserSubscription> subscriptions) async => queued.addAll(subscriptions);

  @override
  Future<List<UserSubscription>> next(int count) async => queued.take(count).toList();

  @override
  Future<void> remove(List<String> ids) async => queued.removeWhere((e) => ids.contains(e.id));

  @override
  Future<int> count() async => queued.length;
}

/// Remembers what it was asked to save, and fails on demand.
class FakeSaver implements SubscriptionSaver {
  final List<List<String>> saved = [];
  int reloads = 0;
  bool failing = false;

  @override
  Future<void> add(List<UserSubscription> subscriptions) async {
    if (failing) throw StateError('database is busy');
    saved.add(subscriptions.map((e) => e.id).toList());
  }

  @override
  Future<void> reload() async => reloads++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A timer that never fires, for tests that do not wait.
class IdleTimer implements Timer {
  @override
  bool get isActive => true;

  @override
  int get tick => 0;

  @override
  void cancel() {}
}

Timer idleTimer(Duration interval, void Function(Timer timer) onTick) => IdleTimer();

UserSubscription subscription(int n) => UserSubscription(
    id: '$n',
    screenName: 'user$n',
    name: 'User $n',
    profileImageUrlHttps: null,
    verified: false,
    createdAt: DateTime(2024),
    inFeed: true);

List<UserSubscription> subscriptions(int count) => List.generate(count, (i) => subscription(i + 1));

UserWithExtra user(int n) => UserWithExtra()
  ..idStr = '$n'
  ..screenName = 'user$n'
  ..name = 'User $n'
  ..verified = false;

TweetChain postBy(String? userId, DateTime? at) => TweetChain(
    id: '$userId-$at',
    tweets: [
      TweetWithCard()
        ..user = (userId == null ? null : (User()..idStr = userId))
        ..createdAt = at
    ],
    isPinned: false);
