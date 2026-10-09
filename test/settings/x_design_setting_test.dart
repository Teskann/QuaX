import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/settings/_theme.dart';

import '../ui/pump_app.dart';

void main() {
  final themePrefs = {
    optionXStyle: false,
    optionThemeMode: 'system',
    optionThemeColor: 'accent',
    optionShowNavigationLabels: false,
  };

  testWidgets('Should offer the X design as the first switch of the appearance settings', (tester) async {
    await pumpInApp(tester, const SettingsThemeFragment(), prefs: themePrefs);

    expect(find.text('X design'), findsOneWidget, reason: 'The setting should be named');
    expect(find.text('Make the interface look like the official X app'), findsOneWidget,
        reason: 'The setting should be explained');
    expect(tester.widgetList<PrefSwitch>(find.byType(PrefSwitch)).first.pref, optionXStyle,
        reason: 'The X design should lead the switches');
  });

  testWidgets('Should flip the preference when the X design is toggled', (tester) async {
    await pumpInApp(tester, const SettingsThemeFragment(), prefs: themePrefs);
    final prefs = PrefService.of(tester.element(find.byType(SettingsThemeFragment)), listen: false);

    await tester.tap(find.text('X design'));
    await tester.pumpAndSettle();
    expect(prefs.get<bool>(optionXStyle), isTrue, reason: 'Toggling on should enable the design');

    await tester.tap(find.text('X design'));
    await tester.pumpAndSettle();
    expect(prefs.get<bool>(optionXStyle), isFalse, reason: 'Toggling off should restore the regular design');
  });
}
