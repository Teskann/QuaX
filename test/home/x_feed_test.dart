import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/home/_x_account.dart';
import 'package:quax/home/_x_feed.dart';
import 'package:quax/home/_x_feed_header.dart';
import 'package:quax/home/_x_timelines.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/user.dart';

import '../ui/fake_images.dart';
import 'x_pump.dart';

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  final groups = [fakeGroup('g1', 'Friends'), fakeGroup('g2', 'News')];

  Widget feed({XFeedTabKind initialKind = XFeedTabKind.forYou, bool withDrawer = false}) => Scaffold(
        drawer: withDrawer ? const Drawer(child: Text('the drawer')) : null,
        body: XFeedScreen(
          scrollController: ScrollController(),
          id: '-1',
          initialKind: initialKind,
          bodyBuilder: (context, tab) => tab.kind == XFeedTabKind.add
              ? XAddTimelinesPage(onAdd: () => showCreateTimelineSheet(context))
              : Text('body ${tab.id}'),
        ),
      );

  TabController tabController(WidgetTester tester) => tester.widget<TabBar>(find.byType(TabBar)).controller!;

  group('XFeedScreen header', () {
    testWidgets('Should show For you, Following, one tab per group and Add', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);

      for (final label in ['For you', 'Following', 'Friends', 'News', 'Add']) {
        expect(find.descendant(of: find.byType(TabBar), matching: find.text(label)), findsOneWidget,
            reason: '$label should be a tab');
      }
      expect(find.byIcon(XIcons.plus), findsOneWidget, reason: 'The Add tab should carry a plus');
    });

    testWidgets('Should open on the tab the user chose as default', (tester) async {
      await pumpXApp(tester, feed(initialKind: XFeedTabKind.following), groups: groups);

      expect(tabController(tester).index, 1, reason: 'Following is the second tab');
      expect(find.text('body following'), findsOneWidget, reason: 'The Following feed should be shown');
    });

    testWidgets('Should show the content of the group whose tab is tapped', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);
      expect(find.text('body forYou'), findsOneWidget, reason: 'For you is the first tab shown');

      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();

      expect(find.text('body g2'), findsOneWidget, reason: 'The tapped group should show its content');
      expect(find.text('body forYou'), findsNothing, reason: 'The previous content should be gone');
    });

    testWidgets('Should select the Add tab and invite to create a timeline', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(tabController(tester).index, 4, reason: 'Add is a real tab, and the last one');
      expect(find.text('Explore your interests'), findsOneWidget, reason: 'The empty state should be the page');
      expect(find.text('See topics that interest you'), findsOneWidget, reason: 'The empty state explains itself');
    });

    testWidgets('Should open the sheet from the Add Timelines button', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Timelines'));
      await tester.pumpAndSettle();

      expect(find.text('Create a timeline'), findsOneWidget, reason: 'The sheet should open');
      expect(find.text('From accounts'), findsOneWidget, reason: 'Timelines can be made of accounts');
      expect(find.text('From a topic'), findsOneWidget, reason: 'Timelines can be made of a topic');
    });

    testWidgets('Should offer the feed settings only on Following and on groups', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);
      expect(find.byIcon(XIcons.dotsThree), findsNothing, reason: 'For you has no settings');

      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(find.byIcon(XIcons.dotsThree), findsOneWidget, reason: 'Following has settings');

      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();
      expect(find.byIcon(XIcons.dotsThree), findsOneWidget, reason: 'A group has settings');

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.byIcon(XIcons.dotsThree), findsNothing, reason: 'The Add page has no settings');
    });

    testWidgets('Should add a tab when a group is created and keep the selected one', (tester) async {
      final app = await pumpXApp(tester, feed(), groups: groups);
      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();

      app.groups.update([...groups, fakeGroup('g3', 'Sports')]);
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byType(TabBar), matching: find.text('Sports')), findsOneWidget,
          reason: 'The new group should appear as a tab');
      expect(find.text('body g2'), findsOneWidget, reason: 'The selected group should stay selected');
    });

    testWidgets('Should fall back to For you when the selected group disappears', (tester) async {
      final app = await pumpXApp(tester, feed(), groups: groups);
      await tester.tap(find.text('News'));
      await tester.pumpAndSettle();

      app.groups.update([groups.first]);
      await tester.pumpAndSettle();

      expect(find.text('body forYou'), findsOneWidget, reason: 'Without its group, the first tab is shown');
    });

    testWidgets('Should share the width between the tabs when they fit', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);

      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isFalse, reason: 'Few tabs share the width');
      expect(tester.widget<TabBar>(find.byType(TabBar)).tabAlignment, TabAlignment.fill,
          reason: 'Fixed tabs fill the bar');
    });

    testWidgets('Should scroll the tabs when they do not fit', (tester) async {
      final many = List.generate(12, (i) => fakeGroup('m$i', 'A long group name $i'));
      await pumpXApp(tester, feed(), groups: many);
      expect(tester.widget<TabBar>(find.byType(TabBar)).isScrollable, isTrue, reason: 'Many tabs scroll');
      expect(tester.widget<TabBar>(find.byType(TabBar)).tabAlignment, TabAlignment.start,
          reason: 'Scrolling tabs start at the left');
    });
  });

  group('XFeedScreen avatar', () {
    testWidgets('Should open the drawer when the avatar is tapped', (tester) async {
      await pumpXApp(tester, feed(withDrawer: true), account: fakeAccountModel(accounts: [fakeAccount('jane')]));
      expect(find.text('the drawer'), findsNothing, reason: 'The drawer starts closed');

      await tester.tap(find.byType(XAccountAvatar));
      await tester.pumpAndSettle();

      expect(find.text('the drawer'), findsOneWidget, reason: 'The avatar should open the home drawer');
    });

    testWidgets('Should show the QuaX logo in the primary text color between the avatar and the actions',
        (tester) async {
      await pumpXApp(tester, feed());

      final logo = tester.widget<Image>(find.byType(Image));
      expect(logo.color, XStyleColors.light.primaryText, reason: 'The monochrome logo takes the text color');
      expect((logo.image as AssetImage).assetName, contains('icon-monochrome'), reason: 'It is the QuaX icon');
    });

    testWidgets('Should show the profile picture of the account', (tester) async {
      await pumpXApp(tester, feed(),
          account: fakeAccountModel(
              accounts: [fakeAccount('jane')], user: fakeUser(image: 'https://example.com/jane_normal.jpg')));

      expect(find.byType(UserAvatar), findsOneWidget, reason: 'The account picture should be the avatar');
      expect(find.byIcon(XIcons.userCircle), findsNothing, reason: 'The fallback is only for unknown accounts');
    });

    testWidgets('Should fall back to a user icon when there is no account', (tester) async {
      await pumpXApp(tester, feed());

      expect(find.byIcon(XIcons.userCircle), findsOneWidget, reason: 'Without an account the avatar is an icon');
    });

    testWidgets('Should fall back to a user icon when the account has no picture', (tester) async {
      await pumpXApp(tester, feed(), account: fakeAccountModel(accounts: [fakeAccount('jane')]));

      expect(find.byIcon(XIcons.userCircle), findsOneWidget, reason: 'No picture, so the generic icon');
    });
  });
}
