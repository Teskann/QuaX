import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/home_screen.dart';
import 'package:pref/pref.dart';

import '../ui/pump_app.dart';

Future<Map<int, FocusNode>> pumpNavigation(WidgetTester tester, List<NavigationPage> pages) async {
  var focusNodes = <int, FocusNode>{};
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => ScaffoldWithBottomNavigation(
        pages: pages,
        prefs: PrefService.of(context, listen: false),
        initialPage: 0,
        builder: (scrollControllers, nodes) {
          focusNodes = Map.of(nodes);
          return pages.map((page) => Text(page.id)).toList();
        },
      ),
    ),
    prefs: {optionShowNavigationLabels: true},
  );
  return focusNodes;
}

void main() {
  final [feed, subscriptions, search, _] = defaultHomePages;

  testWidgets('Should give a focus node to a home tab enabled after the start', (tester) async {
    await pumpNavigation(tester, [feed, subscriptions]);
    final focusNodes = await pumpNavigation(tester, [feed, subscriptions, search]);

    expect(focusNodes.keys, [0, 1, 2],
        reason: 'The Search tab reads its focus node by index, so a tab added later needs one too');
  });

  testWidgets('Should select a home tab enabled after the start when it is tapped', (tester) async {
    await pumpNavigation(tester, [feed, subscriptions]);
    await pumpNavigation(tester, [feed, subscriptions, search]);

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();

    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 2,
        reason: 'The tab shown and the tab highlighted should be the Search tab that was tapped');
  });

  testWidgets('Should drop the focus node of a home tab that was disabled', (tester) async {
    await pumpNavigation(tester, [feed, subscriptions, search]);
    final focusNodes = await pumpNavigation(tester, [feed, subscriptions]);

    expect(focusNodes.keys, [0, 1], reason: 'A removed tab should not keep a focus node');
  });
}
