import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/errors.dart';

import 'pump_app.dart';

Icon cardIcon(WidgetTester tester) =>
    tester.widget<Icon>(find.descendant(of: find.byType(StatusCard), matching: find.byType(Icon)));

Color harmonized(WidgetTester tester, Color color) =>
    color.harmonizeWith(Theme.of(tester.element(find.byType(StatusCard))).colorScheme.primary);

void main() {
  testWidgets('Should show a red error icon by default', (tester) async {
    await pumpInApp(tester, const StatusCard(title: 'Title', details: 'Details', actions: []));

    expect(cardIcon(tester).icon, Icons.error_outline, reason: 'An error is the default level');
    expect(cardIcon(tester).color, harmonized(tester, Colors.red), reason: 'Errors are red, harmonized with the theme');
  });

  testWidgets('Should show an amber warning icon for a warning', (tester) async {
    await pumpInApp(
        tester, const StatusCard(level: StatusLevel.warning, title: 'Title', details: 'Details', actions: []));

    expect(cardIcon(tester).icon, Icons.warning_amber, reason: 'A warning has its own icon');
    expect(cardIcon(tester).color, harmonized(tester, Colors.amber),
        reason: 'Warnings are amber, harmonized with the theme');
  });

  testWidgets('Should prefer the icon it is given over the one of its level', (tester) async {
    await pumpInApp(tester, const StatusCard(icon: Icons.wifi_off, title: 'Title', details: 'Details', actions: []));

    expect(cardIcon(tester).icon, Icons.wifi_off, reason: 'Errors have icons of their own, which should be kept');
    expect(cardIcon(tester).color, harmonized(tester, Colors.red), reason: 'The level still sets the color');
  });

  testWidgets('Should keep the error level for an ErrorCard', (tester) async {
    await pumpInApp(tester, ErrorCard(error: StateError('boom'), stackTrace: null, prefix: (_) => 'Unable to load'));

    expect(tester.widget<StatusCard>(find.byType(StatusCard)).level, StatusLevel.error,
        reason: 'Errors should stay red');
  });
}
