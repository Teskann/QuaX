import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/home_screen.dart';

import '../ui/pump_app.dart';

void main() {
  final pages = [
    NavigationPage('feed', (c) => 'Home', const Icon(Icons.home_outlined), const Icon(Icons.home)),
    NavigationPage('saved', (c) => 'Saved', const Icon(Icons.bookmark_border), const Icon(Icons.bookmark)),
  ];

  Future<NavigationBar> pumpNavigation(WidgetTester tester, {required bool xStyle}) async {
    await pumpInApp(
        tester,
        Builder(
            builder: (context) => ScaffoldWithBottomNavigation(
                pages: pages,
                prefs: PrefService.of(context),
                initialPage: 0,
                builder: (_, _) => const [SizedBox(), SizedBox()])),
        prefs: {optionXStyle: xStyle, optionShowNavigationLabels: true});
    return tester.widget<NavigationBar>(find.byType(NavigationBar));
  }

  testWidgets('Should hide the labels in the X design, whatever the labels preference says', (tester) async {
    final bar = await pumpNavigation(tester, xStyle: true);

    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide, reason: 'X shows icons only');
    expect(find.byType(Divider), findsOneWidget, reason: 'The bar should be topped by a divider');
  });

  testWidgets('Should show the filled icon of the selected page and the outlined one of the others', (tester) async {
    await pumpNavigation(tester, xStyle: true);

    expect(find.byIcon(Icons.home), findsOneWidget, reason: 'The selected page should be filled');
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget, reason: 'Other pages should be outlined');
  });

  testWidgets('Should keep the labels the user asked for outside the X design', (tester) async {
    final bar = await pumpNavigation(tester, xStyle: false);

    expect(bar.labelBehavior, NavigationDestinationLabelBehavior.alwaysShow,
        reason: 'The regular design follows the labels preference');
    expect(find.byType(Divider), findsNothing, reason: 'The regular bar has no divider');
  });
}
