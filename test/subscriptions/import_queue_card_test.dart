import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quax/subscriptions/_import_queue_card.dart';
import 'package:quax/subscriptions/subscription_import_queue.dart';
import 'package:quax/ui/errors.dart';

import '../ui/pump_app.dart';
import 'import_fakes.dart';

void main() {
  Future<SubscriptionImportQueueModel> pumpCard(WidgetTester tester, int waiting) async {
    final store = MemoryImportStore()..queued.addAll(subscriptions(waiting));
    final model = SubscriptionImportQueueModel(store, FakeSaver(), createTimer: idleTimer);
    await tester.runAsync(model.start);
    await pumpInApp(tester, Provider.value(value: model, child: const ImportQueueCard()));
    return model;
  }

  testWidgets('Should say how many subscriptions are left and how fast they come', (tester) async {
    await pumpCard(tester, 85);

    expect(find.text('Importing 85 more subscriptions, 15 per minute'), findsOneWidget,
        reason: 'The user should know what is going on and how long it takes');
  });

  testWidgets('Should say nothing once the queue is empty', (tester) async {
    await pumpCard(tester, 0);

    expect(find.byType(StatusCard), findsNothing, reason: 'There is nothing to tell when nothing is waiting');
  });
}
