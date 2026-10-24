import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/_header.dart';
import 'package:quax/community/community_members_screen.dart';
import 'package:quax/constants.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';
import 'pump_community.dart';

/// The recorded pages of members, in the order the cursors chain them.
List<Fixture> _pagesInOrder() {
  final pages = fixturesOf('membersSliceTimeline_Query');
  String? cursorOf(Fixture page) =>
      page.body['data']['communityResults']['result']['members_slice']['slice_info']['next_cursor'];
  final chain = <Fixture>[];
  String? cursor;
  while (true) {
    final next = pages.where((page) => page.variables['cursor'] == cursor).firstOrNull;
    if (next == null) return chain;
    chain.add(next);
    cursor = cursorOf(next);
  }
}

Future<List<Route<dynamic>>> _openMembers(WidgetTester tester, {FixtureTwitterClient? client}) async {
  final pushed = await openCommunity(tester, client: client);
  await tester.tap(find.byType(CommunityMembersSummary));
  await pumpTransition(tester);
  await pumpUntilLoaded(tester);
  return pushed;
}

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should list the members of the community when the member count is tapped', (tester) async {
    await _openMembers(tester);
    final firstPage = Twitter.parseCommunityMembers(_pagesInOrder().first.body).items;

    expect(find.byType(CommunityMembersScreen), findsOneWidget, reason: 'The member count opens the members');
    expect(find.text('Members of ${community.name}'), findsOneWidget, reason: 'The title names the community');
    final tiles = tester.widgetList<UserTile>(find.byType(UserTile)).map((tile) => tile.user.screenName).toList();
    expect(tiles, isNotEmpty, reason: 'The first page of members should be listed');
    expect(tiles, firstPage.map((user) => user.screenName).take(tiles.length),
        reason: 'The members should keep the order X gives');
  });

  testWidgets('Should load every recorded page of members by following their cursors', (tester) async {
    final client = mockOfX();
    await openCommunity(tester, client: client);
    await tester.tap(find.byType(CommunityMembersSummary));
    await pumpTransition(tester);
    final pages = _pagesInOrder();
    List<String?> answered() => client.answers
        .where((answer) => answer.fixture?.contains('membersSliceTimeline_Query') ?? false)
        .map((answer) => answer.fixture)
        .toList();

    await scrollDownUntil(tester, find.byType(CommunityMembersScreen), () => answered().length == pages.length);

    expect(pages.length, greaterThan(1), reason: 'The capture should hold several pages for this test to mean much');
    expect(answered(), pages.map((page) => page.path),
        reason: 'Each page should be asked with the cursor of the previous one, exactly as the website does');
  });

  testWidgets('Should open the profile of a member when tapped', (tester) async {
    final pushed = await _openMembers(tester);
    final first = tester.widget<UserTile>(find.byType(UserTile).first).user;

    await tester.tap(find.text('@${first.screenName}'));
    await pumpTransition(tester);

    final route = pushed.last;
    expect(route.settings.name, routeProfile, reason: 'A member opens their profile');
    expect((route.settings.arguments as ProfileScreenArguments).screenName, first.screenName,
        reason: 'The profile opened should be the one of the tapped member');
  });

  testWidgets('Should offer to retry when the members cannot be loaded', (tester) async {
    final requested = <String>[];
    await _openMembers(tester,
        client: FixtureTwitterClient(
            {'CommunityQuery': recordedCommunity, 'CommunityTweetsTimeline': recordedPosts()},
            requested: requested));

    expect(find.byType(FullPageErrorWidget), findsOneWidget, reason: 'A failed first page should take the page');
    expect(find.textContaining('Unable to load the members'), findsOneWidget, reason: 'The error should say what failed');

    await tester.tap(find.text('Retry'));
    await pumpUntilLoaded(tester);

    expect(requested.where((operation) => operation == 'membersSliceTimeline_Query'), hasLength(2),
        reason: 'Retry should ask X for the members again');
  });
}
