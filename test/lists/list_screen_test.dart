import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/lists/_header.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/header_banner.dart';
import 'package:quax/ui/users_screen.dart';
import 'package:quax/user.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../mock_x_client.dart';
import '../pump_route.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';
import '../ui/share_mock.dart';
import 'pump_list.dart';

/// Finds [finder] in the header only, not in the posts below it.
Finder _inHeader(Finder finder) => find.descendant(of: find.byType(XListHeader), matching: finder);

String _count(int value) => NumberFormat.compact(locale: 'en').format(value);

/// The count of the header labelled [label], such as Members.
Finder _countOf(String label) => find.byWidgetPredicate((widget) => widget is XListCount && widget.label == label);

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should show the name, the owner, the counts and the banner of the list', (tester) async {
    await openList(tester);
    final list = recordedList;

    expect(find.byType(ErrorCard), findsNothing, reason: 'The recorded list should load without error');
    expect(_inHeader(find.text(list.name)), findsOneWidget, reason: 'The header shows the name of the list');
    expect(
      _inHeader(find.textContaining('@${list.owner!.screenName}', findRichText: true)),
      findsOneWidget,
      reason: 'The header shows who made the list',
    );
    expect(
      _inHeader(find.textContaining('${_count(list.memberCount)} Members', findRichText: true)),
      findsOneWidget,
      reason: 'The header shows how many accounts the list holds',
    );
    expect(
      _inHeader(find.textContaining('${_count(list.followerCount)} Followers', findRichText: true)),
      findsOneWidget,
      reason: 'The header shows how many accounts follow the list',
    );
    expect(find.byType(HeaderBanner), findsOneWidget, reason: 'The recorded list has a banner');
  });

  testWidgets('Should list the latest posts of the members, in the order X gives', (tester) async {
    await openList(tester);
    final firstPage = Twitter.parseListTweets(fixture('ListLatestTweetsTimeline', recordedListId, unstable: true).body);
    final sent = firstPage.chains.map((chain) => chain.tweets.first.idStr).toList();

    final shown = tester.widgetList<TweetTile>(find.byType(TweetTile)).map((tile) => tile.tweet.idStr).toList();
    expect(shown, isNotEmpty, reason: 'The list shows the posts of its members below its header');
    expect(
      sent.where(shown.contains).take(3),
      shown.where(sent.contains).take(3),
      reason: 'The posts should keep the order X gives',
    );
  });

  testWidgets('Should open the profile of the owner when tapped', (tester) async {
    final pushed = await openList(tester);
    final owner = recordedList.owner!;

    await tester.tap(_inHeader(find.textContaining('@${owner.screenName}', findRichText: true)));
    await pumpTransition(tester);

    expect(pushed.single.settings.name, routeProfile, reason: 'The owner of the list opens their profile');
    expect(
      (pushed.single.settings.arguments as ProfileScreenArguments).screenName,
      owner.screenName,
      reason: 'The profile opened should be the one of the owner',
    );
  });

  testWidgets('Should load every page of members the website loads, and no other', (tester) async {
    final client = mockOfX();
    await openList(tester, client: client);
    await tester.tap(_countOf('Members'));
    await pumpTransition(tester);
    final pages = chainPages(listPages('ListMembers'), (page) => Twitter.parseListMembers(page.body).nextCursor);
    final files = pages.map((page) => page.path).toSet();

    expect(find.text('Members of ${recordedList.name}'), findsOneWidget, reason: 'The member count opens the members');
    await scrollDownUntil(
      tester,
      find.byType(UsersScreen),
      () => answeredFixtures(client, files).length == pages.length,
    );
    // Scrolls on past the last page, to catch a request for one more page
    await scrollDownUntil(tester, find.byType(UsersScreen), () => false);

    expect(pages.length, greaterThan(1), reason: 'The capture should hold several pages for this test to mean much');
    expect(
      answeredFixtures(client, files),
      pages.map((page) => page.path),
      reason: 'Each page should be asked with the cursor of the previous one, exactly as the website does',
    );
    expect(
      client.answers.where((answer) => !answer.matched),
      isEmpty,
      reason: 'QuaX should not ask for a page the website never asks for, such as one after the last',
    );
    expect(find.byType(UserTile), findsWidgets, reason: 'Each member is listed');
  });

  testWidgets('Should show the photos of the first members and of a few followers', (tester) async {
    await openList(tester);

    expect(
      find.descendant(of: _countOf('Members'), matching: find.byType(UserAvatar)),
      findsNWidgets(3),
      reason: 'The first page of members gives the photos of three of them',
    );
    expect(
      find.descendant(of: _countOf('Followers'), matching: find.byType(UserAvatar)),
      findsWidgets,
      reason: 'X sends the photos of a few followers with the list',
    );
  });

  testWidgets('Should load every page of followers the website loads', (tester) async {
    final client = mockOfX();
    await openList(tester, client: client);
    await tester.tap(_countOf('Followers'));
    await pumpTransition(tester);
    final pages = chainPages(listPages('ListSubscribers'), (page) => Twitter.parseListFollowers(page.body).nextCursor);
    final files = pages.map((page) => page.path).toSet();

    expect(
      find.text('Followers of ${recordedList.name}'),
      findsOneWidget,
      reason: 'The follower count opens the followers',
    );
    await scrollDownUntil(
      tester,
      find.byType(UsersScreen),
      () => answeredFixtures(client, files).length == pages.length,
    );

    expect(pages.length, greaterThan(1), reason: 'The capture should hold several pages for this test to mean much');
    expect(
      answeredFixtures(client, files),
      pages.map((page) => page.path),
      reason: 'Each page should be asked with the cursor of the previous one, exactly as the website does',
    );
    expect(find.byType(UserTile), findsWidgets, reason: 'Each follower is listed');
  });

  testWidgets('Should open the members on top of the list from a /members link', (tester) async {
    await openList(tester, showMembers: true);
    await pumpTransition(tester);

    expect(find.byType(UsersScreen), findsOneWidget, reason: 'On X, a /members link shows the members of the list');
    await tester.pageBack();
    await pumpTransition(tester);
    expect(find.byType(XListHeader), findsOneWidget, reason: 'Going back shows the list itself');
  });

  testWidgets('Should share the x.com link of the list', (tester) async {
    final shared = recordShares();
    await openList(tester);

    await tester.tap(_inHeader(find.byIcon(Icons.share)));
    await tester.pump();

    expect(shared, ['https://x.com/i/lists/$recordedListId'], reason: 'The shared link should open the list on X');
  });

  testWidgets('Should offer to retry when X sends no list', (tester) async {
    final requested = <String>[];
    await openList(
      tester,
      client: FixtureTwitterClient({
        'ListByRestId': Fixture('empty', {
          'body': {'data': {}},
        }),
      }, requested: requested),
    );

    expect(find.byType(FullPageErrorWidget), findsOneWidget, reason: 'A missing list should show an error');
    await tester.tap(find.text('Retry'));
    await pumpUntilLoaded(tester);

    expect(
      requested.where((operation) => operation == 'ListByRestId'),
      hasLength(2),
      reason: 'Retry should ask X for the list again',
    );
  });
}
