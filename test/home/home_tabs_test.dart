import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/home_screen.dart';

import '../ui/pump_app.dart';

List<NavigationPage> _pages(List<String> ids) => ids
    .map((id) => NavigationPage(id, (_) => id, Icon(Icons.circle, key: Key('icon-$id')), const Icon(Icons.circle)))
    .toList();

Widget _scaffold(List<String> ids) => ScaffoldWithBottomNavigation(
      pages: _pages(ids),
      prefs: PrefServiceCache(defaults: {optionShowNavigationLabels: true}),
      initialPage: 0,
      builder: (scrollControllers, focusNodes) => List.generate(
        ids.length,
        (i) => Focus(
          focusNode: focusNodes[i]!,
          child: ListView(controller: scrollControllers[i]!, children: [Text('page-${ids[i]}')]),
        ),
      ),
    );

void main() {
  testWidgets('Should select a tab added after the first build', (tester) async {
    await pumpInApp(tester, _scaffold(['feed', 'subscriptions']));
    await pumpInApp(tester, _scaffold(['feed', 'subscriptions', 'trending']));

    await tester.tap(find.byKey(const Key('icon-trending')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('icon-trending')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'A tab added later should have a focus node and scroll controller');
    expect(find.text('page-trending'), findsOneWidget, reason: 'The added tab should be shown once selected');
  });

  testWidgets('Should keep working when tabs are removed', (tester) async {
    await pumpInApp(tester, _scaffold(['feed', 'subscriptions', 'trending']));
    await pumpInApp(tester, _scaffold(['feed', 'subscriptions']));

    expect(tester.takeException(), isNull, reason: 'Removing tabs should not break the remaining ones');
    expect(find.text('page-feed'), findsOneWidget, reason: 'The first tab should still be shown');
    expect(find.byKey(const Key('icon-trending')), findsNothing, reason: 'The removed tab should be gone');
  });

  testWidgets('Should keep the focus node of tabs that stay when the count changes', (tester) async {
    await pumpInApp(tester, _scaffold(['feed', 'subscriptions']));
    final before = tester.widget<Focus>(find.byType(Focus).first).focusNode;
    await pumpInApp(tester, _scaffold(['feed', 'subscriptions', 'trending']));

    expect(tester.widget<Focus>(find.byType(Focus).first).focusNode, same(before),
        reason: 'Existing tabs should keep their focus node');
  });
}
