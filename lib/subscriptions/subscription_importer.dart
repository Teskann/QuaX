import 'dart:math';

import 'package:logging/logging.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/recent_activity.dart';
import 'package:quax/subscriptions/subscription_import_queue.dart';
import 'package:quax/user.dart';

/// How many accounts [screenName] follows, and how many QuaX can follow before X rate limits the feeds.
class SubscriptionImportSize {
  final int? count;
  final int limit;

  const SubscriptionImportSize({required this.count, required this.limit});

  bool get exceedsLimit => count != null && count! > limit;
}

/// How far an import went: [collected] followed accounts found, [imported] of them saved right away. The rest is
/// queued and imported a few at a time.
class ImportProgress {
  final int collected;
  final int imported;

  const ImportProgress({required this.collected, this.imported = 0});

  int get queued => collected - imported;
}

/// The most subscriptions [accounts] can follow before X rate limits the feeds, rounded down to the ten, as a precise
/// number such as 256 would wrongly suggest that one more breaks the feeds.
int subscriptionLimit(int accounts) => maxSubscriptionsPerAccount * max<int>(1, accounts) ~/ 10 * 10;

typedef FollowsPage = Future<Follows> Function(String screenName, {String? cursor});
typedef LatestTimelinePage = Future<TweetStatus> Function({String? cursor});

Future<Follows> _followingPage(String screenName, {String? cursor}) =>
    Twitter.getProfileFollows(screenName, 'following', cursor: cursor);

Future<TweetStatus> _latestHomeTimelinePage({String? cursor}) => Twitter.getLatestHomeTimeline(cursor: cursor);

/// Imports the accounts a user follows on X as QuaX subscriptions: the most recently active ones at once, the rest
/// a few at a time through the [queue], so that loading all their feeds does not hit the X rate limits.
class SubscriptionImporter {
  static final log = Logger('SubscriptionImporter');

  final SubscriptionSaver saver;
  final SubscriptionImportQueueModel queue;
  final Future<List<Account>> Function() accounts;
  final FollowsPage follows;
  final LatestTimelinePage latestTimeline;

  const SubscriptionImporter(this.saver, this.queue,
      {this.accounts = getAccounts, this.follows = _followingPage, this.latestTimeline = _latestHomeTimelinePage});

  Future<SubscriptionImportSize> size(String screenName) async {
    final count = (await Twitter.getProfileByScreenName(screenName)).user.friendsCount;
    return SubscriptionImportSize(count: count, limit: subscriptionLimit((await accounts()).length));
  }

  /// Imports at most [maxCount] followed accounts, emitting how many were found so far, then how many were imported.
  Stream<ImportProgress> import(String screenName, int maxCount) async* {
    final collected = <UserSubscription>[];
    await for (final page in _pages(screenName, maxCount)) {
      collected.addAll(page);
      yield ImportProgress(collected: collected.length);
    }

    final ordered = await _byRecentActivity(screenName, collected);
    final now = ordered.take(smartImportFirstBatch).toList();
    final later = ordered.skip(smartImportFirstBatch).toList();
    if (later.isNotEmpty) await queue.enqueue(later);
    if (now.isNotEmpty) await saver.add(now);
    await saver.reload();

    yield ImportProgress(collected: collected.length, imported: now.length);
  }

  Stream<List<UserSubscription>> _pages(String screenName, int maxCount) async* {
    String? cursor;
    int total = 0;
    final seenIds = <String>{};
    final createdAt = DateTime.now();

    while (true) {
      final response = await follows(screenName, cursor: cursor);

      final next = response.cursorBottom;
      final fresh = response.users
          .where((e) => e.idStr != null && seenIds.add(e.idStr!))
          .take(maxCount - total)
          .map((e) => _toSubscription(e, createdAt))
          .toList();
      total = total + fresh.length;

      if (fresh.isNotEmpty) {
        yield fresh;
      }

      if (next == null || next.isEmpty || next == '0' || next == cursor || fresh.isEmpty || total >= maxCount) {
        break;
      }
      cursor = next;
    }
  }

  UserSubscription _toSubscription(UserWithExtra user, DateTime createdAt) => UserSubscription(
      id: user.idStr!,
      name: user.name!,
      profileImageUrlHttps: user.profileImageUrlHttps,
      screenName: user.screenName!,
      verified: user.verified ?? false,
      createdAt: createdAt,
      inFeed: true);

  /// The most recently active first, which only the timeline of a logged in account can tell. The order X gave is
  /// kept for another account, when there is nothing to postpone, or when the timeline can not be read.
  Future<List<UserSubscription>> _byRecentActivity(String screenName, List<UserSubscription> subscriptions) async {
    if (subscriptions.length <= smartImportFirstBatch) {
      return subscriptions;
    }
    try {
      if (!await _isLoggedIn(screenName)) {
        return subscriptions;
      }
      return rankByRecentActivity(subscriptions, (s) => s.id, await _latestChains());
    } catch (e, stackTrace) {
      log.warning('Unable to rank the subscriptions by recent activity, keeping the order of X', e, stackTrace);
      return subscriptions;
    }
  }

  Future<bool> _isLoggedIn(String screenName) async =>
      (await accounts()).any((account) => account.screenName?.toLowerCase() == screenName.toLowerCase());

  Future<List<TweetChain>> _latestChains() async {
    final chains = <TweetChain>[];
    String? cursor;
    for (var page = 0; page < smartImportRankingPages; page++) {
      final status = await latestTimeline(cursor: cursor);
      chains.addAll(status.chains);
      final next = status.cursorBottom;
      if (next == null || next.isEmpty || next == cursor || status.chains.isEmpty) {
        break;
      }
      cursor = next;
    }
    return chains;
  }
}
