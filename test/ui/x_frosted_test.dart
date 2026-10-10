import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/ui/x_frosted.dart';
import 'package:quax/ui/x_style.dart';

import 'pump_app.dart';

void main() {
  Future<void> pumpBar(WidgetTester tester, {required bool disableAnimations}) => pumpInApp(
      tester, const XFrostedBar(child: SizedBox(height: 50)),
      prefs: {optionDisableAnimations: disableAnimations});

  Color barColor(WidgetTester tester) => tester
      .widget<ColoredBox>(find.descendant(of: find.byType(XFrostedBar), matching: find.byType(ColoredBox)))
      .color;

  group('XFrostedBar', () {
    testWidgets('Should blur what is behind the bar', (tester) async {
      await pumpBar(tester, disableAnimations: false);

      expect(find.byType(BackdropFilter), findsOneWidget, reason: 'The bar should apply a single blur');
      expect(barColor(tester).a, closeTo(0.85, 0.01), reason: 'The bar should be translucent');
    });

    testWidgets('Should render opaque without blur when animations are disabled', (tester) async {
      await pumpBar(tester, disableAnimations: true);

      expect(find.byType(BackdropFilter), findsNothing, reason: 'The blur is GPU-expensive and should be skipped');
      expect(barColor(tester), XStyleColors.light.background, reason: 'The bar should be opaque');
    });
  });
}
