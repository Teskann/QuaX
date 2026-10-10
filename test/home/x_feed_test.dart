import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/_x_account.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/_x_feed.dart';
import 'package:quax/home/_x_feed_controller.dart';
import 'package:quax/home/_x_feed_header.dart';
import 'package:quax/home/_x_timelines.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_overlay_feed.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/user.dart';

import '../ui/fake_images.dart';
import 'x_pump.dart';

/// Stands for the topics screen: makes the group 'g3' and gives its id back
Widget _fakeTopics(BuildContext context) => Scaffold(
      body: TextButton(
        onPressed: () {
          context.read<GroupsModel>().update([fakeGroup('g1', 'Friends'), fakeGroup('g2', 'News'), fakeGroup('g3', 'Sports')]);
          Navigator.pop(context, 'g3');
        },
        child: const Text('make the timeline'),
      ),
    );

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
              ? XAddTimelinesPage(onAdd: () => showCreateTimelineSheet(context, topicsBuilder: _fakeTopics))
              : Text('body ${tab.id}'),
        ),
      );

  XFeedController xFeedController(WidgetTester tester) =>
      Provider.of<XFeedController>(tester.element(find.byType(TabBar)), listen: false);

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

    testWidgets('Should size the header like X: 52px toolbar, 44px tabs and a 24px logo', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);

      expect(tester.getSize(find.byType(XFeedHeader)).height, 96, reason: 'The toolbar and the tabs make 52 + 44');
      expect(tester.getSize(find.byType(TabBar)).height, 44, reason: 'The tab bar is 44px');
      expect(tester.getSize(find.byKey(xFeedLogoKey)).height, 24, reason: 'The Q of the logo is 24px, not its margin');
      expect(tester.getSize(find.byType(XAccountAvatar)), const Size(32, 32), reason: 'The avatar is 32px');
    });

    testWidgets('Should show the chevron of For you only while For you is selected', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);
      final chevron = find.descendant(of: find.byType(TabBar), matching: find.byIcon(XIcons.caretDown));
      expect(chevron, findsOneWidget, reason: 'For you is selected, so it carries the chevron');

      await tester.tap(find.text('Following'));
      await tester.pumpAndSettle();
      expect(chevron, findsNothing, reason: 'Another tab is selected, so the chevron is gone');

      await tester.tap(find.text('For you'));
      await tester.pumpAndSettle();
      expect(chevron, findsOneWidget, reason: 'The chevron comes back with the selection');
    });

    testWidgets('Should not show the chevron when the app opens on Following', (tester) async {
      await pumpXApp(tester, feed(initialKind: XFeedTabKind.following), groups: groups);

      expect(find.byIcon(XIcons.caretDown), findsNothing, reason: 'For you is not selected');
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
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('body forYou'), findsOneWidget, reason: 'Without its group, the first tab is shown');
    });

    testWidgets('Should share the width between the tabs when they fit', (tester) async {
      await pumpXApp(tester, feed(), groups: [groups.first]);

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
      expect(tester.widget<TabBar>(find.byType(TabBar)).labelPadding, const EdgeInsets.symmetric(horizontal: 16),
          reason: 'Labels have 16px on each side');
      expect(tester.getTopLeft(find.text('For you')).dx, 16, reason: 'The first tab starts after its padding');
    });

    testWidgets('Should scroll the selected tab into view and show the first one whole when it is selected',
        (tester) async {
      final many = List.generate(12, (i) => fakeGroup('m$i', 'A long group name $i'));
      await pumpXApp(tester, feed(), groups: many);
      final width = tester.getSize(find.byType(TabBar)).width;

      xFeedController(tester).selectGroup('m11');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('A long group name 11')).right, lessThanOrEqualTo(width),
          reason: 'The last tab should be scrolled into view');

      await tester.drag(find.byType(TabBar), const Offset(5000, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('For you'));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('For you')).dx, 16, reason: 'The first tab should not be cut');
    });
  });

  group('XFeedScreen group selection', () {
    testWidgets('Should select the tab of a group created from the Add page', (tester) async {
      final app = await pumpXApp(tester, feed(), groups: groups);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('Explore your interests'), findsOneWidget, reason: 'The Add page is shown');

      app.groups.update([...groups, fakeGroup('g3', 'Sports')]);
      await tester.pumpAndSettle();
      xFeedController(tester).selectGroup('g3');
      await tester.pumpAndSettle();

      expect(tabController(tester).index, 4, reason: 'Sports is the fourth tab after the groups');
      expect(find.text('body g3'), findsOneWidget, reason: 'The new timeline should be the one shown');
    });

    testWidgets('Should select the new group even when it is announced before the tabs reload', (tester) async {
      final app = await pumpXApp(tester, feed(), groups: groups);

      xFeedController(tester).selectGroup('g3');
      app.groups.update([...groups, fakeGroup('g3', 'Sports')]);
      await tester.pumpAndSettle();

      expect(find.text('body g3'), findsOneWidget, reason: 'The selection waits for the group to be there');
    });

    testWidgets('Should select the timeline created from a topic', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Timelines'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('From a topic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('make the timeline'));
      await tester.pumpAndSettle();

      expect(find.text('body g3'), findsOneWidget, reason: 'The group returned by the topic screen is selected');
    });

    testWidgets('Should keep the selected tab when the group announced is unknown', (tester) async {
      await pumpXApp(tester, feed(), groups: groups);

      xFeedController(tester).selectGroup('nope');
      await tester.pumpAndSettle();

      expect(find.text('body forYou'), findsOneWidget, reason: 'An unknown group changes nothing');
    });
  });

  group('XFeedScreen overlay', () {
    const statusBar = 24.0;

    Widget scrollingFeed(List<double> insets) => Scaffold(
          body: XFeedScreen(
            scrollController: ScrollController(),
            id: '-1',
            initialKind: XFeedTabKind.forYou,
            bodyBuilder: (context, tab) => Builder(builder: (context) {
              insets
                ..clear()
                ..addAll([MediaQuery.paddingOf(context).top, XHeaderInset.of(context)]);
              return ListView.builder(
                  itemCount: 100,
                  itemBuilder: (context, i) => SizedBox(height: 100, child: Text('item $i')));
            }),
          ),
        );

    Future<void> withStatusBar(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: statusBar);
      tester.view.viewPadding = const FakeViewPadding(top: statusBar);
      addTearDown(tester.view.reset);
    }

    double headerTop(WidgetTester tester) => tester.getTopLeft(find.byType(XFeedHeader)).dy;

    testWidgets('Should lay the header over the body, which starts below it', (tester) async {
      await withStatusBar(tester);
      final insets = <double>[];
      await pumpXApp(tester, scrollingFeed(insets), groups: groups);

      const inset = statusBar + 52 + 44;
      expect(insets, [inset, inset], reason: 'The body leaves room for the status bar, the toolbar and the tabs');
      expect(tester.getSize(find.byType(XFeedHeader)).height, inset, reason: 'The header covers exactly that room');
      expect(tester.getTopLeft(find.text('item 0')).dy, inset, reason: 'The first item starts below the header');
      expect(tester.getTopLeft(find.byType(ListView)).dy, 0, reason: 'The list itself fills the screen');
    });

    testWidgets('Should let the content scroll under the header', (tester) async {
      await withStatusBar(tester);
      await pumpXApp(tester, scrollingFeed([]), groups: groups);

      await tester.drag(find.byType(ListView), const Offset(0, -40));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(find.text('item 0')).dy, lessThan(statusBar + 52 + 44),
          reason: 'The first item moves up under the header instead of being pushed');
    });

    testWidgets('Should hide the header scrolling down and bring it back scrolling up', (tester) async {
      await withStatusBar(tester);
      await pumpXApp(tester, scrollingFeed([]), groups: groups);
      expect(headerTop(tester), 0, reason: 'The header starts in view');

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(headerTop(tester), -(statusBar + 52 + 44), reason: 'Scrolling down slides the header out of view');

      await tester.drag(find.byType(ListView), const Offset(0, 100));
      await tester.pumpAndSettle();
      expect(headerTop(tester), 0, reason: 'Scrolling up brings the header back');
    });

    testWidgets('Should slide the header over 200ms', (tester) async {
      await pumpXApp(tester, scrollingFeed([]), groups: groups);

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(headerTop(tester), lessThan(0), reason: 'The header is on its way out');
      expect(headerTop(tester), greaterThan(-96), reason: 'The header has not left yet halfway through');
      await tester.pumpAndSettle();
    });

    testWidgets('Should hide the header at once when animations are disabled', (tester) async {
      await pumpXApp(tester, scrollingFeed([]), groups: groups, prefs: {optionDisableAnimations: true});

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();

      expect(headerTop(tester), -96, reason: 'Without animations the header is gone right away');
    });

    testWidgets('Should bring the header back when scrolled to the top by the controller', (tester) async {
      final controller = ScrollController();
      await pumpXApp(
          tester,
          Scaffold(
              body: XFeedScreen(
                  scrollController: controller,
                  id: '-1',
                  initialKind: XFeedTabKind.forYou,
                  bodyBuilder: (context, tab) => ListView.builder(
                      itemCount: 100, itemBuilder: (context, i) => const SizedBox(height: 100)))),
          groups: groups);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(headerTop(tester), -96, reason: 'The header is hidden after scrolling down');

      unawaited(controller.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut));
      await tester.pumpAndSettle();

      expect(headerTop(tester), 0, reason: 'Reselecting the home tab scrolls to the top and shows the header');
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
