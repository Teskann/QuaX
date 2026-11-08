import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/community/_header.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../group/open_feed.dart';
import '../subscriptions/fixtures.dart';
import '../ui/fake_images.dart';
import 'pump_community.dart';

Finder _inHeader(IconData icon) => find.descendant(of: find.byType(CommunityHeader), matching: find.byIcon(icon));

void main() {
  useFreshDatabase();
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should follow a community from its page, and offer to unfollow it then', (tester) async {
    await openCommunity(tester, prefs: subscriptionPrefDefaults);

    await tester.tap(_inHeader(Icons.group_add));
    await pumpUntilFound(tester, find.text('Subscribe'));
    await pumpTransition(tester);
    expect(find.text('Hide from main feed'), findsNothing,
        reason: 'The main feed shows accounts only, so a community has nothing to hide there');
    await tester.tap(find.text('Subscribe'));
    await pumpUntilFound(tester, _inHeader(Icons.group_remove));

    final followed = tester.element(find.byType(CommunityHeader)).read<SubscriptionsModel>().state;
    expect(followed.whereType<CommunitySubscription>().map((c) => c.name), [community.name],
        reason: 'The community should be among the subscriptions, under its name');
  });
}
