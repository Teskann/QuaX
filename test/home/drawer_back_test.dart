import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/home/home_screen.dart';

Future<GlobalKey<ScaffoldState>> _pumpScaffold(WidgetTester tester) async {
  final key = GlobalKey<ScaffoldState>();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(key: key, drawer: const Drawer(child: Text('drawer')), body: const SizedBox()),
  ));
  return key;
}

void main() {
  test('Should do nothing without a scaffold', () {
    expect(closeOpenDrawer(null), isFalse, reason: 'Before the home screen is built there is no drawer to close');
  });

  testWidgets('Should leave the back button alone when the drawer is closed', (tester) async {
    final key = await _pumpScaffold(tester);

    expect(closeOpenDrawer(key.currentState), isFalse,
        reason: 'With the drawer closed, the back button should go on to ask before closing QuaX');
  });

  testWidgets('Should close the drawer when it is open', (tester) async {
    final key = await _pumpScaffold(tester);
    key.currentState!.openDrawer();
    await tester.pumpAndSettle();

    expect(closeOpenDrawer(key.currentState), isTrue, reason: 'An open drawer should take the back button');
    await tester.pumpAndSettle();
    expect(key.currentState!.isDrawerOpen, isFalse, reason: 'The back button should close the drawer');
    expect(find.text('drawer'), findsNothing, reason: 'The drawer should be gone once closed');
  });
}
