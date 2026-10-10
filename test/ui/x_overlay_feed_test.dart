import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/x_overlay_feed.dart';

import 'pump_app.dart';

const _strip = ValueKey('x-status-bar-strip');

Future<void> _pumpFeed(WidgetTester tester, {double statusBar = 24}) async {
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await pumpInApp(
      tester,
      MediaQuery(
        data: MediaQueryData(padding: EdgeInsets.only(top: statusBar), size: const Size(400, 800)),
        child: XOverlayFeed(
          headerHeight: 96,
          scrollController: controller,
          header: const SizedBox(height: 120, child: Text('header')),
          body: ListView.builder(
              controller: controller, itemCount: 100, itemBuilder: (_, i) => SizedBox(height: 80, child: Text('$i'))),
        ),
      ));
}

void main() {
  testWidgets('Should leave the status bar to the header while it shows', (tester) async {
    await _pumpFeed(tester);

    expect(find.byKey(_strip), findsNothing, reason: 'The header already frosts the status bar');
  });

  testWidgets('Should frost the status bar once the header slid away', (tester) async {
    await _pumpFeed(tester);

    await tester.drag(find.text('3'), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byKey(_strip), findsOneWidget, reason: 'The content must not show under the clock');
    expect(tester.getSize(find.byKey(_strip)).height, 24, reason: 'The strip covers the status bar only');
  });

  testWidgets('Should drop the strip when the header comes back', (tester) async {
    await _pumpFeed(tester);
    await tester.drag(find.text('3'), const Offset(0, -400));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, 200));
    await tester.pumpAndSettle();

    expect(find.byKey(_strip), findsNothing, reason: 'The header frosts the status bar again');
  });

  testWidgets('Should not add a strip without a status bar', (tester) async {
    await _pumpFeed(tester, statusBar: 0);
    await tester.drag(find.text('3'), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byKey(_strip), findsNothing, reason: 'There is nothing to cover');
  });
}
