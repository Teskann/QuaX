import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/lists/_header.dart';
import 'package:quax/subscriptions/subscription_kind.dart';

import '../group/open_feed.dart';
import '../subscriptions/follow_from_header.dart';
import '../ui/fake_images.dart';
import 'pump_list.dart';

void main() {
  useFreshDatabase();
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should follow a list from its page, and offer to unfollow it then', (tester) async {
    await openList(tester, prefs: subscriptionPrefDefaults);

    final followed = await followFromHeader(tester, XListHeader, SubscriptionKind.list);

    expect(followed.whereType<ListSubscription>().map((list) => list.name), [recordedList.name],
        reason: 'The list should be among the subscriptions, under its name');
  });
}
