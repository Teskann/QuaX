import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/_x_account.dart';
import 'package:quax/home/_x_drawer.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';

import '../ui/fake_images.dart';
import 'x_pump.dart';

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  final switched = <String>[];

  Widget drawerPage({List<String> pageIds = const ['feed', 'saved', 'subscriptions']}) => Scaffold(
        drawer: XDrawer(
          pageIds: pageIds,
          onSwitchPage: switched.add,
          pageBuilder: (id, _) => Scaffold(body: Text('standalone $id')),
          accountsBuilder: (_) => const Scaffold(body: Text('accounts page')),
        ),
        body: const SizedBox(),
      );

  Future<XTestApp> pumpDrawer(
    WidgetTester tester, {
    List<String> pageIds = const ['feed', 'saved', 'subscriptions'],
    bool account = true,
    Brightness brightness = Brightness.light,
    Map<String, dynamic> prefs = const {},
    int? following = 69,
    int? followers = 8,
  }) async {
    switched.clear();
    final app = await pumpXApp(tester, drawerPage(pageIds: pageIds),
        account: fakeAccountModel(
            accounts: account ? [fakeAccount('jane')] : const [],
            user: fakeUser(following: following, followers: followers)),
        brightness: brightness,
        prefs: prefs);
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    return app;
  }

  group('XDrawer header', () {
    testWidgets('Should show the name, the handle and the follow counts of the account', (tester) async {
      await pumpDrawer(tester);

      expect(find.text('Jane Doe'), findsOneWidget, reason: 'The name of the account should be shown');
      expect(find.text('@jane'), findsOneWidget, reason: 'The handle of the account should be shown');
      expect(find.textContaining('69'), findsOneWidget, reason: 'The number of followed accounts should be shown');
      expect(find.textContaining('Following'), findsOneWidget, reason: 'The count should be labelled');
      expect(find.textContaining('Followers'), findsOneWidget, reason: 'The followers count should be labelled');
      expect(find.text('Add account'), findsNothing, reason: 'There is an account already');
    });

    testWidgets('Should size the drawer like X', (tester) async {
      await pumpDrawer(tester);

      TextStyle? styleOf(String text) => tester.widget<Text>(find.text(text)).style;
      expect(styleOf('Jane Doe')?.fontSize, 20, reason: 'The name is 20px');
      expect(styleOf('Jane Doe')?.fontWeight, FontWeight.w800, reason: 'The name is extra bold');
      expect(styleOf('@jane')?.fontSize, 15, reason: 'The handle is 15px');
      expect(styleOf('Profile')?.fontSize, 20, reason: 'Primary items read at 20px');
      expect(styleOf('Profile')?.fontWeight, FontWeight.w700, reason: 'Primary items are bold');
      expect(styleOf('Settings and privacy')?.fontSize, 16, reason: 'Secondary items read at 16px');
      expect(tester.getSize(find.ancestor(of: find.text('Profile'), matching: find.byType(SizedBox)).first).height, 52,
          reason: 'Primary rows are 52px high');
      expect(
          tester.getSize(find.ancestor(of: find.text('Settings and privacy'), matching: find.byType(SizedBox)).first).height,
          40,
          reason: 'Secondary rows are 40px high');
    });

    testWidgets('Should take 93% of a narrow screen', (tester) async {
      tester.view
        ..physicalSize = const Size(360, 800)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpDrawer(tester);

      expect(tester.getSize(find.byType(Drawer)).width, moreOrLessEquals(360 * 0.93),
          reason: 'The drawer leaves a strip of the page visible');
    });

    testWidgets('Should stop at 400px on a wide screen', (tester) async {
      await pumpDrawer(tester);

      expect(tester.getSize(find.byType(Drawer)).width, 400, reason: 'The drawer never gets wider than 400');
    });

    testWidgets('Should draw a 36px avatar and a 28px outlined more button with a 16px icon', (tester) async {
      await pumpDrawer(tester);

      expect(tester.getSize(find.byType(XAccountAvatar)), const Size(36, 36), reason: 'The avatar is 36px');
      final button = find.ancestor(of: find.byIcon(XIcons.dotsThreeVertical), matching: find.byType(Container)).first;
      expect(tester.getSize(button), const Size(28, 28), reason: 'The circle of the button is 28px');
      final decoration = tester.widget<Container>(button).decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle, reason: 'The button is a circle');
      expect(decoration.border, Border.all(color: XStyleColors.light.secondaryText),
          reason: 'The circle has a 1px outline in secondary text');
      expect(tester.widget<Icon>(find.byIcon(XIcons.dotsThreeVertical)).size, 16, reason: 'The icon is 16px');
    });

    testWidgets('Should inset the dividers by 16px and start the first item right after the first one',
        (tester) async {
      await pumpDrawer(tester);

      final dividers = tester.widgetList<Divider>(find.byType(Divider)).toList();
      expect(dividers, hasLength(2), reason: 'One divider under the header and one above the secondary items');
      expect(dividers.map((e) => (e.indent, e.endIndent)), everyElement((16.0, 16.0)),
          reason: 'Dividers stop 16px short of both edges');
      final profile = find.ancestor(of: find.text('Profile'), matching: find.byType(SizedBox)).first;
      expect(tester.getTopLeft(profile).dy, tester.getBottomLeft(find.byType(Divider).first).dy,
          reason: 'The first item has no padding above it');
    });

    testWidgets('Should hide the counts the profile did not tell', (tester) async {
      await pumpDrawer(tester, following: null, followers: null);

      expect(find.textContaining('Followers'), findsNothing, reason: 'Unknown counts should not be invented');
      expect(find.text('Jane Doe'), findsOneWidget, reason: 'The rest of the header should still be there');
    });

    testWidgets('Should invite to add an account when there is none', (tester) async {
      await pumpDrawer(tester, account: false);

      expect(find.text('Add account'), findsOneWidget, reason: 'Without an account the user can add one');
      expect(find.text('Jane Doe'), findsNothing, reason: 'There is no name to show');
    });

    testWidgets('Should open the accounts from the dots button', (tester) async {
      await pumpDrawer(tester);

      await tester.tap(find.byIcon(XIcons.dotsThreeVertical));
      await tester.pumpAndSettle();

      expect(find.text('accounts page'), findsOneWidget, reason: 'The accounts screen should open');
    });
  });

  group('XDrawer items', () {
    testWidgets('Should open the profile of the account', (tester) async {
      final app = await pumpDrawer(tester);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(app.pushed, [routeProfile], reason: 'The profile route should open');
      expect(find.text('Profile'), findsNothing, reason: 'The drawer should close');
    });

    testWidgets('Should do nothing for the profile when there is no account', (tester) async {
      final app = await pumpDrawer(tester, account: false);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(app.pushed, isEmpty, reason: 'There is no profile to open');
    });

    testWidgets('Should switch to the saved page when it is in the navigation', (tester) async {
      await pumpDrawer(tester);

      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      expect(switched, ['saved'], reason: 'Bookmarks is the saved page of the navigation');
      expect(find.text('standalone saved'), findsNothing, reason: 'It should not be pushed too');
    });

    testWidgets('Should push the saved page when it is not in the navigation', (tester) async {
      await pumpDrawer(tester, pageIds: const ['feed']);

      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      expect(find.text('standalone saved'), findsOneWidget, reason: 'The saved page should open on its own');
      expect(switched, isEmpty, reason: 'There is no page to switch to');
    });

    testWidgets('Should switch to the subscriptions page when it is in the navigation', (tester) async {
      await pumpDrawer(tester);

      await tester.tap(find.text('Lists'));
      await tester.pumpAndSettle();

      expect(switched, ['subscriptions'], reason: 'Lists is the subscriptions page of the navigation');
    });

    testWidgets('Should push the subscriptions page when it is not in the navigation', (tester) async {
      await pumpDrawer(tester, pageIds: const ['feed']);

      await tester.tap(find.text('Lists'));
      await tester.pumpAndSettle();

      expect(find.text('standalone subscriptions'), findsOneWidget, reason: 'The page should open on its own');
    });

    testWidgets('Should open the settings', (tester) async {
      final app = await pumpDrawer(tester);

      await tester.tap(find.text('Settings and privacy'));
      await tester.pumpAndSettle();

      expect(app.pushed, [routeSettings], reason: 'The settings route should open');
    });

    testWidgets('Should offer the search only when it is not in the navigation', (tester) async {
      await pumpDrawer(tester, pageIds: const ['feed', 'trending']);
      expect(find.text('Search'), findsNothing, reason: 'The search is one tap away in the navigation');
    });

    testWidgets('Should open the search when it is not in the navigation', (tester) async {
      final app = await pumpDrawer(tester, pageIds: const ['feed']);

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(app.pushed, [routeSearch], reason: 'The search route should open');
    });

    testWidgets('Should not offer what QuaX does not support', (tester) async {
      await pumpDrawer(tester);

      for (final label in ['Communities', 'Spaces', 'Premium', 'Creator Studio']) {
        expect(find.text(label), findsNothing, reason: '$label is not supported');
      }
    });
  });

  group('XDrawer theme button', () {
    testWidgets('Should switch to the light theme from the dark one', (tester) async {
      final app = await pumpDrawer(tester, brightness: Brightness.dark, prefs: {optionThemeMode: 'dark'});
      expect(find.byIcon(XIcons.moonStars), findsOneWidget, reason: 'Dark shows the moon');

      await tester.tap(find.byIcon(XIcons.moonStars));

      expect(app.prefs.get<String>(optionThemeMode), 'light', reason: 'Dark flips to light');
    });

    testWidgets('Should switch to the dark theme from the light one', (tester) async {
      final app = await pumpDrawer(tester, prefs: {optionThemeMode: 'system'});
      expect(find.byIcon(XIcons.sun), findsOneWidget, reason: 'Light shows the sun');

      await tester.tap(find.byIcon(XIcons.sun));

      expect(app.prefs.get<String>(optionThemeMode), 'dark', reason: 'Light flips to dark');
    });
  });

  group('Drawer of the home scaffold', () {
    final pages = [
      NavigationPage('feed', (c) => 'Home', const Icon(Icons.home_outlined), const Icon(Icons.home)),
      NavigationPage('saved', (c) => 'Saved', const Icon(Icons.bookmark_border), const Icon(Icons.bookmark)),
    ];

    Future<void> pumpHome(WidgetTester tester, {required bool xStyle}) async {
      await pumpXApp(
          tester,
          Builder(
              builder: (context) => ScaffoldWithBottomNavigation(
                  pages: pages,
                  prefs: PrefService.of(context),
                  initialPage: 0,
                  builder: (_, _) => const [Text('feed page'), Text('saved page')])),
          prefs: {optionXStyle: xStyle, optionShowNavigationLabels: false});
      tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
      await tester.pumpAndSettle();
    }

    testWidgets('Should switch the navigation to the saved page from the X drawer', (tester) async {
      await pumpHome(tester, xStyle: true);

      await tester.tap(find.text('Bookmarks'));
      await tester.pumpAndSettle();

      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1,
          reason: 'The saved page should be selected in the navigation');
      expect(find.text('saved page'), findsOneWidget, reason: 'The saved page should be shown');
    });

    testWidgets('Should keep the regular drawer outside the X design', (tester) async {
      await pumpHome(tester, xStyle: false);

      expect(find.text('Settings'), findsOneWidget, reason: 'The regular drawer lists the settings');
      expect(find.text('Search'), findsOneWidget, reason: 'The regular drawer lists the search');
      expect(find.text('Bookmarks'), findsNothing, reason: 'The X entries belong to the X design');
    });
  });
}
