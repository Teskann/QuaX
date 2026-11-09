import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/constants.dart';
import 'package:quax/community/_header.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_kind.dart';

import '../group/open_feed.dart';
import '../subscriptions/follow_from_header.dart';
import '../ui/fake_images.dart';
import 'pump_community.dart';

void main() {
  useFreshDatabase();
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should follow a community from its page, and offer to unfollow it then', (tester) async {
    await openCommunity(tester, prefs: subscriptionPrefDefaults);

    final followed = await followFromHeader(tester, CommunityHeader, SubscriptionKind.community);

    expect(followed.whereType<CommunitySubscription>().map((c) => c.name), [community.name],
        reason: 'The community should be among the subscriptions, under its name');
  });
}
