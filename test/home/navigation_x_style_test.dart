import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/ui/x_icons.dart';

import '../ui/pump_app.dart';

void main() {
  final pages = [
    NavigationPage('feed', (c) => 'Home', const Icon(Icons.home_outlined), const Icon(Icons.home)),
    NavigationPage('saved', (c) => 'Saved', const Icon(Icons.bookmark_border), const Icon(Icons.bookmark)),
    NavigationPage('group-1', (c) => 'Group', const Icon(Icons.group_outlined), const Icon(Icons.group)),
  ];

  Future<void> pumpNavigation(
    WidgetTester tester, {
    required bool xStyle,
    Widget Function(int index)? pageAt,
  }) =>
      pumpInApp(
          tester,
          Builder(
              builder: (context) => ScaffoldWithBottomNavigation(
                  pages: pages,
                  prefs: PrefService.of(context),
                  initialPage: 0,
                  builder: (_, _) => List.generate(pages.length, pageAt ?? (_) => const SizedBox()))),
          prefs: {optionXStyle: xStyle, optionShowNavigationLabels: true});

  NavigationBar bar(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar));

  Scaffold homeScaffold(WidgetTester tester) => tester
      .widget<Scaffold>(find.ancestor(of: find.byType(NavigationBar), matching: find.byType(Scaffold)).first);

  testWidgets('Should hide the labels in the X design, whatever the labels preference says', (tester) async {
    await pumpNavigation(tester, xStyle: true);

    expect(bar(tester).labelBehavior, NavigationDestinationLabelBehavior.alwaysHide, reason: 'X shows icons only');
    expect(find.byType(Divider), findsOneWidget, reason: 'The bar should be topped by a divider');
  });

  testWidgets('Should show the filled icon of the selected page and the outlined one of the others', (tester) async {
    await pumpNavigation(tester, xStyle: true);

    expect(find.byIcon(XIcons.navigation['feed']!.$2), findsOneWidget, reason: 'The selected page should be filled');
    expect(find.byIcon(XIcons.navigation['saved']!.$1), findsOneWidget, reason: 'Other pages should be outlined');
    expect(find.byIcon(Icons.home), findsNothing, reason: 'The X design should not use the Material icon');
  });

  testWidgets('Should size the X icons of the bar', (tester) async {
    await pumpNavigation(tester, xStyle: true);

    final icon = tester.widget<Icon>(find.byIcon(XIcons.navigation['feed']!.$2));
    expect(icon.size, XIcons.navSize, reason: 'The icons of the bar should be 24px');
  });

  testWidgets('Should keep the icon of pages the X design has no icon for', (tester) async {
    await pumpNavigation(tester, xStyle: true);

    expect(find.byIcon(Icons.group_outlined), findsOneWidget, reason: 'Unmapped pages keep their own icon');
  });

  testWidgets('Should keep the Material icons outside the X design', (tester) async {
    await pumpNavigation(tester, xStyle: false);

    expect(find.byIcon(Icons.home), findsOneWidget, reason: 'The regular design keeps the Material icons');
    expect(find.byIcon(Icons.bookmark_border), findsOneWidget, reason: 'Other pages keep their Material icon');
    expect(find.byIcon(XIcons.navigation['feed']!.$2), findsNothing, reason: 'The X icons belong to the X design');
  });

  testWidgets('Should keep the labels the user asked for outside the X design', (tester) async {
    await pumpNavigation(tester, xStyle: false);

    expect(bar(tester).labelBehavior, NavigationDestinationLabelBehavior.alwaysShow,
        reason: 'The regular design follows the labels preference');
    expect(find.byType(Divider), findsNothing, reason: 'The regular bar has no divider');
  });

  testWidgets('Should let the content scroll under the frosted bar in the X design', (tester) async {
    await pumpNavigation(tester, xStyle: true);

    expect(homeScaffold(tester).extendBody, isTrue, reason: 'The content should reach under the translucent bar');
    expect(find.byType(BackdropFilter), findsOneWidget, reason: 'The bar should blur what scrolls under it');
  });

  testWidgets('Should not blur anything in the regular design', (tester) async {
    await pumpNavigation(tester, xStyle: false);

    expect(homeScaffold(tester).extendBody, isFalse, reason: 'The regular bar does not overlap the content');
    expect(find.byType(BackdropFilter), findsNothing, reason: 'The regular bar is opaque');
  });

  testWidgets('Should keep the last item of a list reachable above the frosted bar', (tester) async {
    await pumpNavigation(tester,
        xStyle: true,
        pageAt: (_) => ListView.builder(
            itemCount: 30, itemBuilder: (_, i) => SizedBox(height: 60, child: Text('item $i'))));

    await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();

    expect(tester.getBottomLeft(find.text('item 29')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byType(NavigationBar)).dy),
        reason: 'The last item should end above the bar once scrolled to the end');
  });
}
