import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/home/_x_timelines.dart';
import 'package:quax/home/_x_topics.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_sheet.dart';
import 'package:quax/ui/x_style.dart';

import 'x_pump.dart';

void main() {
  group('XCreateTimelineSheet', () {
    final calls = <String>[];

    Future<void> openSheet(WidgetTester tester) async {
      calls.clear();
      await pumpXApp(
          tester,
          Builder(
              builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet(
                      context: context,
                      builder: (_) => XCreateTimelineSheet(
                          onFromAccounts: () => calls.add('accounts'), onFromTopic: () => calls.add('topic'))),
                  child: const Text('open'))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('Should offer to create a timeline from accounts or from a topic', (tester) async {
      await openSheet(tester);

      expect(find.text('Create a timeline'), findsOneWidget, reason: 'The sheet should be titled');
      expect(find.text('From accounts'), findsOneWidget, reason: 'Accounts are one way to make a timeline');
      expect(find.text('From a topic'), findsOneWidget, reason: 'A topic is the other way');
    });

    testWidgets('Should use the X sheet, which ends with a Cancel button that closes it', (tester) async {
      await openSheet(tester);

      expect(find.byType(XSheet), findsOneWidget, reason: 'The sheet has the chrome of the X design');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Create a timeline'), findsNothing, reason: 'Cancel closes the sheet');
      expect(calls, isEmpty, reason: 'Cancel starts nothing');
    });

    testWidgets('Should close the sheet and start the accounts flow', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('From accounts'));
      await tester.pumpAndSettle();

      expect(calls, ['accounts'], reason: 'Only the accounts flow should start');
      expect(find.text('Create a timeline'), findsNothing, reason: 'The sheet should close');
    });

    testWidgets('Should close the sheet and start the topic flow', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text('From a topic'));
      await tester.pumpAndSettle();

      expect(calls, ['topic'], reason: 'Only the topic flow should start');
      expect(find.text('Create a timeline'), findsNothing, reason: 'The sheet should close');
    });
  });

  group('showCreateTimelineSheet', () {
    testWidgets('Should open the screen to pick a topic', (tester) async {
      final app = await pumpXApp(
          tester,
          Builder(
              builder: (context) =>
                  TextButton(onPressed: () => showCreateTimelineSheet(context), child: const Text('open'))));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('From a topic'));
      await tester.pumpAndSettle();

      expect(find.byType(XTopicsScreen), findsOneWidget, reason: 'A topic is picked among trends and categories');
      expect(app.pushed, isEmpty, reason: 'The search screen is not the way to make a topic timeline anymore');
    });
  });

  group('XAddTimelinesPage', () {
    testWidgets('Should invite to explore interests with a pill button', (tester) async {
      var added = 0;
      await pumpXApp(tester, XAddTimelinesPage(onAdd: () => added++));
      final colors = XStyleColors.light;

      expect(find.text('Explore your interests'), findsOneWidget, reason: 'The page needs its title');
      expect(find.text('See topics that interest you'), findsOneWidget, reason: 'The page needs its subtitle');
      final icon = tester.widget<Icon>(find.byIcon(XIcons.timelines));
      expect(icon.size, 44, reason: 'The illustration is 44px');
      expect(icon.color, colors.secondaryText, reason: 'The illustration is discreet');
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.style!.backgroundColor!.resolve({}), colors.primaryText, reason: 'The pill is in primary text');
      expect(button.style!.foregroundColor!.resolve({}), colors.background, reason: 'Its label is in background');

      await tester.tap(find.text('Add Timelines'));
      expect(added, 1, reason: 'The button should ask to add a timeline');
    });

    testWidgets('Should size and space the invitation like X', (tester) async {
      await pumpXApp(tester, const XAddTimelinesPage(onAdd: _noop));

      final title = tester.widget<Text>(find.text('Explore your interests')).style!;
      expect([title.fontSize, title.fontWeight], [19, FontWeight.w800], reason: 'The title is 19 w800');
      final subtitle = tester.widget<Text>(find.text('See topics that interest you')).style!;
      expect(subtitle.fontSize, 15, reason: 'The subtitle is 15');
      expect(subtitle.color, XStyleColors.light.secondaryText, reason: 'The subtitle is secondary');
      final icon = tester.getRect(find.byIcon(XIcons.timelines));
      final titleBox = tester.getRect(find.text('Explore your interests'));
      final subtitleBox = tester.getRect(find.text('See topics that interest you'));
      final button = tester.getRect(find.byType(FilledButton));
      expect(titleBox.top - icon.bottom, 12, reason: 'The title is 12px under the icon');
      expect(subtitleBox.top - titleBox.bottom, 4, reason: 'The subtitle is 4px under the title');
      expect(button.top - subtitleBox.bottom, 20, reason: 'The button is 20px under the subtitle');
      expect(button.height, 36, reason: 'The pill is 36px tall');
      final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
      expect(style.padding!.resolve({}), const EdgeInsets.symmetric(horizontal: 20), reason: 'The pill has 20px sides');
      expect(style.textStyle!.resolve({})!.fontSize, 15, reason: 'The label is 15');
      expect(style.textStyle!.resolve({})!.fontWeight, FontWeight.w700, reason: 'The label is w700');
    });

    testWidgets('Should center the invitation slightly above the middle of the page', (tester) async {
      await pumpXApp(tester, const XAddTimelinesPage(onAdd: _noop));

      final page = tester.getRect(find.byType(XAddTimelinesPage));
      final group = tester.getRect(find.byIcon(XIcons.timelines)).expandToInclude(tester.getRect(find.byType(FilledButton)));
      expect((group.center.dy - page.top) / page.height, closeTo(0.45, 0.01),
          reason: 'The invitation sits at 45% of the height of the page');
    });
  });
}

void _noop() {}
