import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_import_queue.dart';

import 'import_fakes.dart';

void main() {
  late MemoryImportStore store;
  late FakeSaver saver;

  setUp(() {
    store = MemoryImportStore();
    saver = FakeSaver();
  });

  SubscriptionImportQueueModel model() => SubscriptionImportQueueModel(store, saver);

  group('SubscriptionImportQueueModel', () {
    test('Should not start a timer when the queue is empty', () {
      fakeAsync((async) {
        final queue = model();
        queue.start();
        async.flushMicrotasks();

        expect(queue.isRunning, isFalse, reason: 'There is nothing to wait for');
        expect(queue.state, 0, reason: 'Nothing is waiting');
      });
    });

    test('Should import nothing before the first interval', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(40));
        final queue = model()..start();
        async.elapse(smartImportInterval - const Duration(seconds: 1));

        expect(saver.saved, isEmpty, reason: 'The first batch was imported with the import itself');
        expect(queue.state, 40, reason: 'The whole queue should still be waiting');
      });
    });

    test('Should import one batch per minute, in queue order', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(40));
        final queue = model()..start();

        async.elapse(smartImportInterval);
        expect(saver.saved.single.length, smartImportBatch, reason: 'A batch should be imported each minute');
        expect(saver.saved.single.first, '1', reason: 'The lowest position should go first');
        expect(queue.state, 40 - smartImportBatch, reason: 'The imported accounts should leave the queue');

        async.elapse(smartImportInterval);
        expect(saver.saved.last.first, '16', reason: 'The next batch should continue where the last stopped');
        expect(saver.reloads, 0, reason: 'The feeds should not reload while accounts are still waiting');
      });
    });

    test('Should reload the app once, after the last batch', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(40));
        model().start();

        async.elapse(smartImportInterval * 2);
        expect(saver.saved.length, 2, reason: 'Two batches should be saved');
        expect(saver.reloads, 0, reason: 'Batches before the last one should not reload anything');

        async.elapse(smartImportInterval);
        expect(saver.saved.length, 3, reason: 'The last batch should be saved');
        expect(saver.reloads, 1, reason: 'The app should be told once the queue is empty');

        async.elapse(smartImportInterval * 3);
        expect(saver.reloads, 1, reason: 'Nothing more should reload once the queue is empty');
      });
    });

    test('Should count down the waiting accounts on each tick', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(40));
        final queue = model()..start();
        final counts = <int>[];
        queue.observer(onState: counts.add);

        async.elapse(smartImportInterval * 3);

        expect(counts, [40, 25, 10, 0], reason: 'The count should start full and drop by a batch every minute');
      });
    });

    test('Should not reload when a batch fails to save', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(10));
        model().start();
        saver.failing = true;

        async.elapse(smartImportInterval * 2);

        expect(saver.reloads, 0, reason: 'Nothing was saved, so nothing changed');
      });
    });

    test('Should stop its timer once the queue is empty', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(20));
        final queue = model()..start();

        async.elapse(smartImportInterval * 2);
        expect(queue.state, 0, reason: 'Both batches should be done');
        expect(queue.isRunning, isFalse, reason: 'A drained queue should not keep waking the app up');

        async.elapse(smartImportInterval * 3);
        expect(saver.saved.length, 2, reason: 'Nothing should be imported once the queue is empty');
        expect(saver.saved.last.length, 5, reason: 'The last batch should hold what is left');
      });
    });

    test('Should resume from a persisted queue when started again', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(30));
        model().start();
        async.elapse(smartImportInterval);

        final restarted = model()..start();
        async.elapse(smartImportInterval);

        expect(restarted.state, 0, reason: 'The restarted model should finish what the first one left');
        expect(saver.saved.map((e) => e.length), [15, 15], reason: 'No account should be imported twice or lost');
      });
    });

    test('Should keep the batch in the queue when the import fails, and retry on the next tick', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(20));
        final queue = model()..start();
        saver.failing = true;

        async.elapse(smartImportInterval);
        expect(queue.state, 20, reason: 'A failed batch should not be dropped');
        expect(queue.isRunning, isTrue, reason: 'The model should keep trying');

        saver.failing = false;
        async.elapse(smartImportInterval);
        expect(saver.saved.single.first, '1', reason: 'The same batch should be retried first');
        expect(queue.state, 20 - smartImportBatch, reason: 'The retry should empty the batch from the queue');
      });
    });

    test('Should start draining as soon as accounts are enqueued', () {
      fakeAsync((async) {
        final queue = model();
        queue.enqueue(subscriptions(3));
        async.flushMicrotasks();

        expect(queue.isRunning, isTrue, reason: 'Queued accounts should not wait for the next launch');
        expect(queue.state, 3, reason: 'The count should include the new accounts');

        async.elapse(smartImportInterval);
        expect(queue.state, 0, reason: 'The queued accounts should be imported');
        expect(queue.isRunning, isFalse, reason: 'The timer should stop with the queue');
      });
    });

    test('Should keep earlier accounts first when enqueuing again', () {
      fakeAsync((async) {
        final queue = model();
        queue.enqueue(subscriptions(2));
        queue.enqueue([subscription(10)]);
        async.elapse(smartImportInterval);

        expect(saver.saved.single, ['1', '2', '10'], reason: 'New accounts should queue behind the waiting ones');
      });
    });

    test('Should not overlap two imports when one is slow', () {
      fakeAsync((async) {
        store.queued.addAll(subscriptions(50));
        final slow = SlowSaver();
        final queue = SubscriptionImportQueueModel(store, slow)..start();

        async.elapse(smartImportInterval * 3);
        expect(slow.started, 1, reason: 'A tick should be skipped while the previous batch is still importing');
        slow.finish();
        async.flushMicrotasks();
        expect(queue.state, 35, reason: 'The slow batch should complete normally');
      });
    });
  });
}

class SlowSaver extends FakeSaver {
  final _done = Completer<void>();
  int started = 0;

  @override
  Future<void> add(List<UserSubscription> subscriptions) {
    started++;
    return _done.future;
  }

  void finish() => _done.complete();
}
