import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/_list.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../ui/pump_app.dart';

/// The model sits above the app, as in the real one, since the drag proxy lives in the overlay.
Widget Function(Widget) _withModel(List<Subscription> subscriptions) => (app) => Provider(
      create: (context) {
        final prefs = PrefService.of(context, listen: false);
        return SubscriptionsModel(prefs, GroupsModel(prefs))..update(subscriptions);
      },
      child: app,
    );

void main() {
  testWidgets('Should keep rendering a subscription while it is dragged', (tester) async {
    final subscriptions = ['first', 'second', 'third']
        .map((id) => SearchSubscription(id: id, createdAt: DateTime(2024)))
        .toList();
    await pumpInApp(tester, const CustomScrollView(slivers: [SubscriptionUsers()]),
        prefs: {optionSubscriptionOrderCustom: ''}, aboveApp: _withModel(subscriptions));

    final gesture = await tester.startGesture(tester.getCenter(find.text('first')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull, reason: 'The drag proxy should have a Material ancestor for its tile');
    expect(find.text('first'), findsWidgets, reason: 'The dragged subscription should still be shown');

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
