import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_editor.dart';
import 'package:quax/subscriptions/add_to_groups_sheet.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../group/open_feed.dart';
import '../ui/pump_app.dart';
import 'fixtures.dart';

/// Opens the editor of the group [groupId], or of a new group, once what [follow] stored is loaded.
Future<void> _openEditor(WidgetTester tester, {String? groupId}) async {
  await _pumpApp(tester, (context) => openGroupEditor(context, id: groupId));
  await pumpUntilFound(tester, find.byType(CheckboxListTile));
  // Lets the page slide in, so that taps land on it
  await tester.pumpAndSettle();
}

/// Shows a button running [open], and taps it once the subscriptions are loaded.
Future<void> _pumpApp(WidgetTester tester, void Function(BuildContext context) open) async {
  useTallScreen(tester);
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => TextButton(onPressed: () => open(context), child: const Text('Open')),
    ),
    prefs: subscriptionPrefDefaults,
    aboveApp: withSubscriptionModels(),
    settle: false,
  );
  await pumpUntil(
    tester,
    () => tester.element(find.text('Open')).read<SubscriptionsModel>().state.isNotEmpty,
    reason: 'the subscriptions should load',
  );
  await tester.tap(find.text('Open'));
}

bool? _ticked(WidgetTester tester, String name) =>
    tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, name)).value;

FilledButton _saveButton(WidgetTester tester) => tester.widget(find.widgetWithText(FilledButton, 'Save'));

List<SubscriptionGroup> _groups(WidgetTester tester) =>
    tester.element(find.byType(Navigator)).read<GroupsModel>().state;

void main() {
  useFreshDatabase();

  testWidgets('Should keep an unticked member in place until the group is saved', (tester) async {
    final groupId = await tester.runAsync(() async {
      await follow(['alice', 'bob', 'zoe'].map(account).toList());
      return createGroup('Friends', [account('zoe')]);
    });
    await _openEditor(tester, groupId: groupId);
    expectAbove(tester, 'zoe', 'alice', reason: 'The members of the group should come first (#282)');

    await tester.tap(find.text('zoe'));
    await tester.pump();

    expect(_ticked(tester, 'zoe'), isFalse, reason: 'The member should be unticked');
    expectAbove(tester, 'zoe', 'alice', reason: 'Unticking a member should not move it');
  });

  testWidgets('Should enable Save only once the group changed', (tester) async {
    final groupId = await tester.runAsync(() async {
      await follow([account('alice')]);
      return createGroup('Friends', []);
    });
    await _openEditor(tester, groupId: groupId);
    expect(_saveButton(tester).onPressed, isNull, reason: 'There is nothing to save before a change');

    await tester.tap(find.text('alice'));
    await tester.pump();

    expect(_saveButton(tester).onPressed, isNotNull, reason: 'The change can be saved');
  });

  testWidgets('Should save the name, the members and the color of a group', (tester) async {
    await tester.runAsync(() => follow([account('alice'), savedSearch('flutter')]));
    await _openEditor(tester);

    await tester.enterText(find.byType(TextField).first, 'Tech');
    await tester.tap(find.text('flutter'));
    await tester.tap(find.byTooltip('Color and icon'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Color 1'));
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await pumpUntilGone(tester, find.byType(GroupEditorScreen));

    final group = _groups(tester).single;
    expect(group.name, 'Tech', reason: 'The group should have the name typed');
    expect(group.color, isNotNull, reason: 'The group should have the color picked');
    expect(await membersOf(tester, group.id), {
      refOf(savedSearch('flutter')),
    }, reason: 'The ticked saved search should be the only member');
  });

  testWidgets('Should start a group made from the selection with the selected subscriptions ticked', (tester) async {
    await tester.runAsync(() => follow([account('alice'), account('bob')]));
    await _pumpApp(tester, (context) => showGroupsSheet(context, [account('alice')], onDone: () {}));
    await pumpUntilFound(tester, find.text('New group'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('New group'));
    await pumpUntilFound(tester, find.byType(GroupEditorScreen));
    await pumpUntilFound(tester, find.byType(CheckboxListTile));

    expect(_ticked(tester, 'alice'), isTrue, reason: 'The selected account should be in the new group');
    expect(_ticked(tester, 'bob'), isFalse, reason: 'The other account should not');
  });

  testWidgets('Should delete a group once confirmed', (tester) async {
    final groupId = await tester.runAsync(() async {
      await follow([account('alice')]);
      return createGroup('Friends', [account('alice')]);
    });
    await _openEditor(tester, groupId: groupId);

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await pumpUntilGone(tester, find.byType(GroupEditorScreen));

    expect(_groups(tester), isEmpty, reason: 'The group should be gone');
  });

  testWidgets('Should ask for a name instead of saving a group without one', (tester) async {
    await tester.runAsync(() => follow([account('alice')]));
    await _openEditor(tester);
    await tester.tap(find.text('alice'));
    await tester.pump();

    await tester.tap(find.text('Save'));
    await pumpUntilFound(tester, find.text('Please enter a name'));

    expect(find.byType(GroupEditorScreen), findsOneWidget, reason: 'The editor should stay open');
  });

  testWidgets('Should ask before dropping changes, and keep them when editing goes on', (tester) async {
    await tester.runAsync(() => follow([account('alice')]));
    await _openEditor(tester);
    await tester.tap(find.text('alice'));
    await tester.pump();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget, reason: 'Closing with changes should ask first');

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupEditorScreen), findsOneWidget, reason: 'The editor should stay open');
    expect(_ticked(tester, 'alice'), isTrue, reason: 'The change should be kept');
  });

  testWidgets('Should show first a color picked outside the quick choices', (tester) async {
    final groupId = await tester.runAsync(() async {
      await follow([account('alice')]);
      return createGroup('Friends', [], color: Colors.brown);
    });
    await _openEditor(tester, groupId: groupId);

    await tester.tap(find.byTooltip('Color and icon'));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp(r'^Color \d+$')).first),
      isSemantics(label: 'Color 17', isSelected: true),
      reason: 'The color of the group should show, selected, in the first place of the quick choices',
    );
  });
}
