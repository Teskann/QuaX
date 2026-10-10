import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/home/_x_timelines.dart';
import 'package:quax/home/_x_topics.dart';
import 'package:quax/ui/x_icons.dart';
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
      expect(icon.size, 64, reason: 'The illustration is large');
      expect(icon.color, colors.secondaryText, reason: 'The illustration is discreet');
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.style!.backgroundColor!.resolve({}), colors.primaryText, reason: 'The pill is in primary text');
      expect(button.style!.foregroundColor!.resolve({}), colors.background, reason: 'Its label is in background');

      await tester.tap(find.text('Add Timelines'));
      expect(added, 1, reason: 'The button should ask to add a timeline');
    });

    testWidgets('Should center the invitation vertically', (tester) async {
      await pumpXApp(tester, const XAddTimelinesPage(onAdd: _noop));

      final page = tester.getCenter(find.byType(XAddTimelinesPage));
      final content = tester.getCenter(find.text('Explore your interests'));
      expect((content.dy - page.dy).abs(), lessThan(100), reason: 'The invitation sits in the middle of the page');
    });
  });
}

void _noop() {}
