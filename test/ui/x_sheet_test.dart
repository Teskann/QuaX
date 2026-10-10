import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_sheet.dart';
import 'package:quax/ui/x_style.dart';

import 'pump_app.dart';

void main() {
  final taps = <String>[];

  Future<void> openSheet(WidgetTester tester, {String? title = 'A title'}) async {
    taps.clear();
    await pumpInApp(
        tester,
        Builder(
            builder: (context) => TextButton(
                onPressed: () => showXSheet<void>(
                    context,
                    (_) => XSheet(title: title, children: [
                          XSheetRow(icon: XIcons.repost, label: 'First row', onTap: () => taps.add('first')),
                          XSheetRow(icon: XIcons.search, label: 'Second row', onTap: () => taps.add('second')),
                        ])),
                child: const Text('open'))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('XSheet', () {
    testWidgets('Should draw a 36x4 grabber 8px from the top, in secondary text at 40% opacity', (tester) async {
      await openSheet(tester);

      final grabber = find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 36);
      expect(tester.getSize(grabber), const Size(36, 4), reason: 'The grabber is 36x4');
      final decoration = tester.widget<Container>(grabber).decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(2), reason: 'The grabber has 2px corners');
      expect(decoration.color, XStyleColors.light.secondaryText.withValues(alpha: 0.4),
          reason: 'The grabber is discreet');
      final sheetTop = tester.getTopLeft(find.byType(XSheet)).dy;
      expect(tester.getTopLeft(grabber).dy - sheetTop, 9, reason: 'The grabber is 8px under the 1px border');
    });

    testWidgets('Should paint the background of X under a divider-colored border and round the top by 16px',
        (tester) async {
      await openSheet(tester);

      final surfaces = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(XSheet), matching: find.byType(DecoratedBox)))
          .map((e) => e.decoration)
          .whereType<ShapeDecoration>()
          .toList();
      expect(surfaces.map((e) => e.color), [XStyleColors.light.divider, XStyleColors.light.background],
          reason: 'The border is the surface behind the background, which shows 1px of it on top');
      expect((surfaces.first.shape as RoundedRectangleBorder).borderRadius,
          const BorderRadius.vertical(top: Radius.circular(16)),
          reason: 'The top corners are 16px');
    });

    testWidgets('Should title the sheet at 17px extra bold, aligned to the left with a 16px margin', (tester) async {
      await openSheet(tester);

      final title = tester.widget<Text>(find.text('A title'));
      expect([title.style!.fontSize, title.style!.fontWeight], [17, FontWeight.w800], reason: 'The title is 17 w800');
      expect(title.textAlign, TextAlign.start, reason: 'The title is on the left');
      expect(tester.getTopLeft(find.text('A title')).dx - tester.getTopLeft(find.byType(XSheet)).dx, 16,
          reason: 'The title has a 16px margin');
    });

    testWidgets('Should leave out the title when there is none', (tester) async {
      await openSheet(tester, title: null);

      expect(find.text('A title'), findsNothing, reason: 'A sheet without title has no title');
      expect(find.text('First row'), findsOneWidget, reason: 'The rows are still there');
    });

    testWidgets('Should draw rows of 52px with a 22px icon and a 17px bold label', (tester) async {
      await openSheet(tester);

      final row = find.byType(XSheetRow).first;
      expect(tester.getSize(row).height, 52, reason: 'Rows are 52px high');
      expect(tester.widget<Icon>(find.byIcon(XIcons.repost)).size, 22, reason: 'Row icons are 22px');
      final label = tester.widget<Text>(find.text('First row'));
      expect([label.style!.fontSize, label.style!.fontWeight], [17, FontWeight.w700], reason: 'Labels are 17 w700');
    });

    testWidgets('Should run the action of the row that is tapped', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('Second row'));

      expect(taps, ['second'], reason: 'Only the tapped row acts');
    });

    testWidgets('Should end with a full-width outlined Cancel pill of 40px that closes the sheet', (tester) async {
      await openSheet(tester);

      final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
      final sheet = tester.getRect(find.byType(XSheet));
      expect(tester.getSize(cancel).height, 40, reason: 'The pill is 40px high');
      expect(tester.getSize(cancel).width, sheet.width - 32, reason: 'The pill spans the sheet with 16px margins');
      final style = tester.widget<OutlinedButton>(cancel).style!;
      expect(style.side!.resolve({}), BorderSide(color: XStyleColors.light.secondaryText),
          reason: 'The outline is 1px in secondary text');
      expect(style.shape!.resolve({}), isA<StadiumBorder>(), reason: 'The button is a pill');
      expect(style.textStyle!.resolve({})!.fontSize, 15, reason: 'The label is 15px');
      expect(style.textStyle!.resolve({})!.fontWeight, FontWeight.w700, reason: 'The label is bold');
      expect(sheet.bottom - tester.getRect(cancel).bottom, 16, reason: 'The pill has a 16px margin below it');

      await tester.tap(cancel);
      await tester.pumpAndSettle();

      expect(find.byType(XSheet), findsNothing, reason: 'Cancel closes the sheet');
      expect(taps, isEmpty, reason: 'Cancel does not act');
    });
  });
}
