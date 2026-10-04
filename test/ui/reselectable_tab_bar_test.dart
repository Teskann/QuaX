import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/reselectable_tab_bar.dart';

import 'pump_app.dart';

class _Tabs extends StatefulWidget {
  final List<int> reselected;

  const _Tabs(this.reselected);

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> with SingleTickerProviderStateMixin {
  late final TabController controller = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        ReselectableTabBar(
          controller: controller,
          tabs: const [Tab(text: 'First'), Tab(text: 'Second'), Tab(text: 'Third')],
          onReselect: widget.reselected.add,
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: const [Text('first page'), Text('second page'), Text('third page')],
          ),
        ),
      ]);
}

Future<List<int>> pumpTabs(WidgetTester tester) async {
  final reselected = <int>[];
  await pumpInApp(tester, _Tabs(reselected));
  return reselected;
}

void main() {
  testWidgets('Should not report the first tap on a tab that was not selected', (tester) async {
    final reselected = await pumpTabs(tester);

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    expect(reselected, isEmpty, reason: 'Opening a tab is not reselecting it, so no menu should come with it');
    expect(find.text('second page'), findsOneWidget, reason: 'The tab should still open');
  });

  testWidgets('Should report the second tap on the tab that is now selected', (tester) async {
    final reselected = await pumpTabs(tester);

    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    expect(reselected, [1], reason: 'Tapping the tab already shown should report its index, once');
  });

  testWidgets('Should report a tap on the tab that is selected from the start', (tester) async {
    final reselected = await pumpTabs(tester);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();

    expect(reselected, [0], reason: 'The first tab is already shown at the start, so tapping it is a reselection');
  });

  testWidgets('Should not report a tap on another tab after one was reselected', (tester) async {
    final reselected = await pumpTabs(tester);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Third'));
    await tester.pumpAndSettle();

    expect(reselected, [0], reason: 'Going to another tab must not be reported as a reselection');
  });

  testWidgets('Should report a tap on a tab reached by swiping', (tester) async {
    final reselected = await pumpTabs(tester);

    await tester.fling(find.byType(TabBarView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('second page'), findsOneWidget, reason: 'The swipe should have opened the second tab');
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();

    expect(reselected, [1], reason: 'A tab opened by swiping is selected, so tapping it is a reselection');
  });
}
