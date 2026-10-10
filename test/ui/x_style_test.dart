import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/ui/x_style.dart';

import 'pump_app.dart';

void main() {
  group('buildXTheme', () {
    test('Should use the light palette of X in the light theme', () {
      final theme = buildXTheme(Brightness.light);

      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF), reason: 'Light X is white');
      expect(theme.colorScheme.primary, const Color(0xFF1D9BF0), reason: 'The accent is X blue');
      expect(theme.colorScheme.onSurface, const Color(0xFF0F1419), reason: 'Primary text is near black');
      expect(theme.colorScheme.onSurfaceVariant, const Color(0xFF536471), reason: 'Secondary text is grey');
      expect(theme.dividerTheme.color, const Color(0xFFEFF3F4), reason: 'Dividers are light grey');
    });

    test('Should use the Lights out palette of X in the dark theme', () {
      final theme = buildXTheme(Brightness.dark);

      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000), reason: 'Dark X is pure black');
      expect(theme.colorScheme.surface, const Color(0xFF000000), reason: 'Surfaces are pure black too');
      expect(theme.colorScheme.onSurface, const Color(0xFFE7E9EA), reason: 'Primary text is near white');
      expect(theme.colorScheme.outlineVariant, const Color(0xFF2F3336), reason: 'Dividers are dark grey');
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF000000), reason: 'The app bar blends with the page');
    });

    test('Should draw flat 1px dividers, app bars and cards', () {
      final theme = buildXTheme(Brightness.light);

      expect(theme.dividerTheme.thickness, 1, reason: 'Dividers are hairlines');
      expect(theme.dividerTheme.indent, 0, reason: 'Dividers span the full width');
      expect(theme.appBarTheme.scrolledUnderElevation, 0, reason: 'The app bar never changes tone when scrolled');
      expect(theme.cardTheme.elevation, 0, reason: 'Cards are flat');
      expect(theme.cardTheme.margin, EdgeInsets.zero, reason: 'Cards touch each other');
    });

    test('Should hide the navigation labels and the selection indicator', () {
      final navigation = buildXTheme(Brightness.dark).navigationBarTheme;

      expect(navigation.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide, reason: 'X shows icons only');
      expect(navigation.indicatorColor, Colors.transparent, reason: 'X has no pill behind the selected icon');
      expect(navigation.height, 52, reason: 'The bar is compact');
      expect(navigation.iconTheme!.resolve({})!.size, 24, reason: 'The icons are 24px');
    });

    test('Should use the Inter font everywhere', () {
      final theme = buildXTheme(Brightness.light);

      expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter', reason: 'Inter stands for the Chirp font of X');
      expect(theme.textTheme.titleLarge!.fontFamily, 'Inter', reason: 'Every text style uses it, not only the body');
    });

    test('Should underline the selected tab over the full tab width with a rounded 2.5px bar', () {
      final tabs = buildXTheme(Brightness.light).tabBarTheme;
      final indicator = tabs.indicator as UnderlineTabIndicator;

      expect(indicator.borderSide.width, 2.5, reason: 'The underline is 2.5px thick');
      expect(indicator.borderRadius, BorderRadius.circular(2), reason: 'The underline has rounded ends');
      expect(tabs.indicatorSize, TabBarIndicatorSize.tab, reason: 'The underline spans the whole tab');
      expect(tabs.dividerHeight, 1, reason: 'A 1px divider closes the tab bar');
      expect(tabs.labelStyle!.fontSize, 15, reason: 'Tab labels are 15px');
      expect(tabs.labelStyle!.fontWeight, FontWeight.w700, reason: 'Tab labels are bold');
      expect(indicator.borderSide.color, XStyleColors.light.primaryText, reason: 'The underline is not blue');
      expect(tabs.labelColor, XStyleColors.light.primaryText, reason: 'The selected tab reads in primary text');
      expect(tabs.unselectedLabelColor, XStyleColors.light.secondaryText, reason: 'Other tabs read in secondary text');
    });
  });

  group('appTextScaler', () {
    test('Should ignore the text scale of the app in the X design', () {
      final scaler = appTextScaler(xStyle: true, appFactor: 1.5, systemFactor: 1.2);

      expect(scaler.scale(10), closeTo(12, 0.001), reason: 'X follows the system text scale only');
    });

    test('Should apply the text scale of the app on top of the system one in the regular design', () {
      final scaler = appTextScaler(xStyle: false, appFactor: 1.5, systemFactor: 1.2);

      expect(scaler.scale(10), closeTo(18, 0.001), reason: 'The regular design multiplies both scales');
    });
  });

  group('isXStyle', () {
    Future<bool> readStyle(WidgetTester tester, Map<String, dynamic> prefs) async {
      late bool result;
      await pumpInApp(
          tester,
          Builder(builder: (context) {
            result = isXStyle(context);
            return verifiedColor(context) == XStyleColors.verified ? const Text('x') : const Text('themed');
          }),
          prefs: prefs);
      return result;
    }

    testWidgets('Should be on when the preference is set', (tester) async {
      expect(await readStyle(tester, {optionXStyle: true}), isTrue, reason: 'The preference turns the design on');
      expect(find.text('x'), findsOneWidget, reason: 'The verified badge is X blue in the X design');
    });

    testWidgets('Should be off when the preference is off or never set', (tester) async {
      expect(await readStyle(tester, {optionXStyle: false}), isFalse, reason: 'The design is opt-in');
      expect(find.text('themed'), findsOneWidget, reason: 'The verified badge follows the theme otherwise');
      expect(await readStyle(tester, {}), isFalse, reason: 'A missing preference counts as off');
    });
  });
}
