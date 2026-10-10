import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/_x_drawer.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/ui/x_icons.dart';

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
