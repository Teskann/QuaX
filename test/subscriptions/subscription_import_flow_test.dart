import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_import_queue.dart';
import 'package:quax/subscriptions/subscription_importer.dart';
import 'package:quax/user.dart';

import 'import_fakes.dart';

void main() {
  late MemoryImportStore store;
  late FakeSaver saver;
  late int timelineRequests;
  late Future<TweetStatus> Function(String? cursor) timeline;
  late Future<List<Account>> Function() accounts;

  setUp(() {
    store = MemoryImportStore();
    saver = FakeSaver();
    timelineRequests = 0;
    timeline = (_) async => throw StateError('The timeline should not be read');
    accounts = () async => [Account(id: '1', authHeader: '', screenName: 'Me')];
  });

  Future<Follows> followsPage(List<UserWithExtra> all, String? cursor) async {
    final start = int.parse(cursor ?? '0');
    final end = start + 40 < all.length ? start + 40 : all.length;
    return Follows(cursorBottom: end < all.length ? '$end' : null, cursorTop: null, users: all.sublist(start, end));
  }

  SubscriptionImporter importer(int following) {
    final all = List.generate(following, (i) => user(i + 1));
    return SubscriptionImporter(saver, SubscriptionImportQueueModel(store, saver, createTimer: idleTimer),
        accounts: () => accounts(),
        follows: (screenName, {cursor}) => followsPage(all, cursor),
        latestTimeline: ({cursor}) {
          timelineRequests++;
          return timeline(cursor);
        });
  }

  Future<ImportProgress> run(SubscriptionImporter importer, {String screenName = 'me', int maxCount = 1 << 31}) =>
      importer.import(screenName, maxCount).last;

  TweetStatus page(List<TweetChain> chains, {String? next}) =>
      TweetStatus(chains: chains, cursorBottom: next, cursorTop: null);

  List<String> firstImported() => saver.saved.single;

  group('SubscriptionImporter batching', () {
    final cases = {
      0: (0, 0),
      1: (1, 0),
      60: (60, 0),
      smartImportFirstBatch: (smartImportFirstBatch, 0),
      smartImportFirstBatch + 1: (smartImportFirstBatch, 1),
      smartImportFirstBatch + smartImportBatch * 3 + 7: (smartImportFirstBatch, smartImportBatch * 3 + 7),
    };
    for (final MapEntry(key: following, value: (first, queued)) in cases.entries) {
      test('Should import $first right away and queue $queued when following $following', () async {
        final progress = await run(importer(following));

        expect(saver.saved.fold<int>(0, (sum, batch) => sum + batch.length), first,
            reason: 'Only the first batch should be imported at once');
        expect(store.queued.length, queued, reason: 'Everything else should wait in the queue');
        expect(progress.imported, first, reason: 'The screen should be told how many were imported now');
        expect(progress.queued, queued, reason: 'The screen should be told how many are still to come');
        expect(saver.reloads, 1, reason: 'The app should be told once that subscriptions changed');
      });
    }

    test('Should import no more than the number the user chose', () async {
      final progress = await run(importer(300), maxCount: 120);

      expect(progress.collected, 120, reason: 'The choice of the user caps what is collected');
      expect(store.queued.length, 20, reason: 'Only the chosen accounts beyond the first batch should be queued');
    });

    test('Should report the accounts found so far while collecting', () async {
      final progress = await importer(100).import('me', 1 << 31).toList();

      expect(progress.map((e) => e.collected), [40, 80, 100, 100],
          reason: 'Each page found should be reported, then the final summary');
      expect(progress.take(3).map((e) => e.imported), [0, 0, 0], reason: 'Nothing is imported while collecting');
    });

    test('Should queue the accounts in the order they follow', () async {
      await run(importer(130));

      expect(store.queued.map((e) => e.id).take(3), ['101', '102', '103'],
          reason: 'The accounts after the first batch should wait in order');
    });
  });

  group('SubscriptionImporter ranking', () {
    final noon = DateTime(2024, 1, 1, 12);

    test('Should import the most recently active accounts first for a logged in account', () async {
      timeline = (_) async => page([postBy('150', noon), postBy('149', noon.subtract(const Duration(hours: 1)))]);

      await run(importer(150));

      expect(firstImported().take(3), ['150', '149', '1'],
          reason: 'Active accounts should jump the queue, the others keep their order');
      expect(firstImported().length, smartImportFirstBatch, reason: 'The first batch size should not change');
      expect(store.queued.map((e) => e.id), contains('100'), reason: 'The pushed back accounts should be queued');
    });

    test('Should match the logged in account without caring about the case', () async {
      timeline = (_) async => page([postBy('150', noon)]);

      await run(importer(150), screenName: 'ME');

      expect(firstImported().first, '150', reason: 'X usernames are case insensitive');
    });

    test('Should keep the order of X for an account that is not logged in', () async {
      await run(importer(150), screenName: 'someoneelse');

      expect(timelineRequests, 0, reason: 'The timeline of another account is not readable');
      expect(firstImported().first, '1', reason: 'Without activity, X order should be kept');
    });

    test('Should not read the timeline when everything is imported at once', () async {
      await run(importer(smartImportFirstBatch));

      expect(timelineRequests, 0, reason: 'Ranking would cost requests for no visible effect');
    });

    test('Should keep the order of X when the timeline fails', () async {
      timeline = (_) async => throw StateError('rate limited');

      final progress = await run(importer(150));

      expect(firstImported().first, '1', reason: 'A failing ranking should not prevent the import');
      expect(progress.imported, smartImportFirstBatch, reason: 'The import should complete');
    });

    test('Should keep the order of X when a later page of the timeline fails', () async {
      timeline = (cursor) async => cursor == null ? page([postBy('150', noon)], next: 'c1') : throw StateError('429');

      await run(importer(150));

      expect(firstImported().first, '1', reason: 'A partial ranking is not trusted, any error skips it');
    });

    test('Should keep the order of X when the accounts can not be read', () async {
      accounts = () async => throw StateError('no database');

      await run(importer(150));

      expect(firstImported().first, '1', reason: 'Not knowing the accounts should only skip the ranking');
    });

    test('Should read at most the pages allowed', () async {
      timeline = (cursor) async => page([postBy('150', noon)], next: '${timelineRequests}x');

      await run(importer(150));

      expect(timelineRequests, smartImportRankingPages, reason: 'The ranking should cost a bounded number of requests');
    });

    test('Should stop reading the timeline when there is no next page', () async {
      timeline = (_) async => page([postBy('150', noon)]);

      await run(importer(150));

      expect(timelineRequests, 1, reason: 'The last page has no cursor to follow');
    });

    test('Should stop reading the timeline when a page is empty', () async {
      timeline = (_) async => page([], next: 'again');

      await run(importer(150));

      expect(timelineRequests, 1, reason: 'An empty page means the timeline is over');
    });
  });
}
