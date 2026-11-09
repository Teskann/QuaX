import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_display.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../pump_route.dart';
import 'fixtures.dart';

/// Follows what the page shows with the follow button of its [header], and waits for the button to offer to unfollow.
/// Also checks that the menu does not offer to hide it from the main feed. Gives the subscriptions then.
Future<List<Subscription>> followFromHeader(WidgetTester tester, Type header, SubscriptionKind kind) async {
  Finder inHeader(IconData icon) => find.descendant(of: find.byType(header), matching: find.byIcon(icon));

  await tester.tap(inHeader(kind.followIcon));
  await pumpUntilFound(tester, find.text('Subscribe'));
  await pumpTransition(tester);
  expect(find.text('Hide from main feed'), findsNothing,
      reason: 'The main feed shows accounts only, so a ${kind.name} has nothing to hide there');
  await tester.tap(find.text('Subscribe'));
  await pumpUntilFound(tester, inHeader(kind.unfollowIcon));

  return tester.element(find.byType(header)).read<SubscriptionsModel>().state;
}
