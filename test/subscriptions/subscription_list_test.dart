import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/subscriptions/_groups.dart';
import 'package:quax/subscriptions/_list.dart';
import 'package:quax/subscriptions/_search_field.dart';
import 'package:quax/subscriptions/_selection.dart';
import 'package:quax/subscriptions/subscriptions.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/back_interceptors.dart';

import '../group/open_feed.dart';
import '../ui/pump_app.dart';
import 'fixtures.dart';

/// Opens the page on what [follow] and [createGroup] stored, once [shownFirst] shows.
/// [onAppClosed] runs when back would close the app.
Future<void> _openPage(
  WidgetTester tester,
  String shownFirst, {
  Map<String, Object> prefs = const {},
  VoidCallback? onAppClosed,
}) async {
  useTallScreen(tester);
  await pumpInApp(
    tester,
    BackInterceptorsScope(
      onBackNotUsed: (_) => onAppClosed?.call(),
      child: SubscriptionsScreen(scrollController: ScrollController()),
    ),
    prefs: {...subscriptionPrefDefaults, ...prefs},
    aboveApp: withSubscriptionModels(),
    settle: false,
  );
  await pumpUntilFound(tester, _row(shownFirst));
}

Finder _row(String name) => find.widgetWithText(SubscriptionRow, name);

/// The tag of [group] under the row of [name], once the memberships are loaded.
Finder _tag(String name, String group) => find.descendant(of: _row(name), matching: find.text(group));

Finder _groupTile(String name) => find.descendant(of: find.byType(GroupsGrid), matching: find.text(name));

Future<void> _select(WidgetTester tester, List<String> names) async {
  await tester.longPress(_row(names.first));
  for (final name in names.skip(1)) {
    await tester.tap(_row(name));
  }
  await tester.pump();
}

/// Selects [names] and opens the sheet to add them to groups.
Future<void> _addToGroups(WidgetTester tester, List<String> names) async {
  await _select(tester, names);
  await tester.tap(find.byTooltip('Add to groups'));
  await tester.pumpAndSettle();
}

/// Drags the handle of the row of [name] down by [rows] rows.
Future<void> _dragDown(WidgetTester tester, String name, {required double rows}) async {
  final handle = find.descendant(of: _row(name), matching: find.byIcon(Icons.drag_indicator));
  final rowHeight = tester.getSize(_row(name)).height;
  final gesture = await tester.startGesture(tester.getCenter(handle));
  await tester.pump(const Duration(milliseconds: 100));
  for (var step = 0; step < 10; step++) {
    await gesture.moveBy(Offset(0, rowHeight * rows / 10));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  useFreshDatabase();

  testWidgets('Should move a subscription dragged by its handle, and keep that order', (tester) async {
    await tester.runAsync(() => follow(['first', 'second', 'third'].map(account).toList()));
    await _openPage(tester, 'first', prefs: {optionSubscriptionOrderByField: 'custom'});

    await _dragDown(tester, 'first', rows: 1);
    expect(tester.takeException(), isNull, reason: 'The dragged row should draw without error');
    expectAbove(tester, 'second', 'first', reason: '"first" should now be below "second"');
    expectAbove(tester, 'first', 'third', reason: '"first" should stay above "third"');

    // Reloading reads the order back from the preferences, as when the app starts again
    await tester.runAsync(() => context(tester).read<SubscriptionsModel>().reloadSubscriptions());
    await tester.pumpAndSettle();
    expectAbove(tester, 'second', 'first', reason: 'The new order should still show the next time the app starts');
  });

  testWidgets('Should start the custom order from the order shown', (tester) async {
    await tester.runAsync(
      () => follow([account('older', subscribedAt: DateTime(2020)), account('newer', subscribedAt: DateTime(2025))]),
    );
    await _openPage(
      tester,
      'older',
      prefs: {optionSubscriptionOrderByField: 'created_at', optionSubscriptionOrderByAscending: false},
    );
    expectAbove(tester, 'newer', 'older', reason: 'The newest subscription should come first when sorted that way');

    await tester.tap(find.byTooltip('Sort by'));
    await tester.pumpAndSettle();

    expect(find.text('Custom'), findsOneWidget, reason: 'The sort after the date should be the custom order');
    expectAbove(tester, 'newer', 'older', reason: 'The custom order should start as the subscriptions were shown');
  });

  testWidgets('Should close the search on back, without closing the app', (tester) async {
    var appClosed = false;
    await tester.runAsync(() => follow([account('alice')]));
    await _openPage(tester, 'alice', onAppClosed: () => appClosed = true);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byType(CompactSearchField), findsNothing, reason: 'Back should close the search');
    expect(appClosed, isFalse, reason: 'Back should not close the app while the search is open');

    await tester.binding.handlePopRoute();
    expect(appClosed, isTrue, reason: 'Once the search is closed, back should close the app');
  });

  testWidgets('Should clear the selection on back, before closing the search', (tester) async {
    var appClosed = false;
    await tester.runAsync(() => follow([account('alice')]));
    await _openPage(tester, 'alice', onAppClosed: () => appClosed = true);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    await _select(tester, ['alice']);

    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(find.byType(SelectionAppBar), findsNothing, reason: 'Back should clear the selection first');
    expect(appClosed, isFalse, reason: 'Back should not close the app while subscriptions are selected');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CompactSearchField), findsNothing, reason: 'The next back should close the search');
  });

  testWidgets('Should let back close the app when the subscriptions page is in another tab', (tester) async {
    var appClosed = false;
    await tester.runAsync(() => follow([account('alice')]));
    await _openPage(tester, 'alice', onAppClosed: () => appClosed = true);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    context(tester).read<BackInterceptors>().shownPage = 'feed';

    await tester.binding.handlePopRoute();

    expect(appClosed, isTrue, reason: 'A search left open in a tab not on screen should not use the back button');
  });

  testWidgets('Should unsubscribe from the selection, and bring it back with its groups on Undo', (tester) async {
    await tester.runAsync(() async {
      await follow([account('alice'), account('bob')]);
      await createGroup('Friends', [account('alice')]);
    });
    await _openPage(tester, 'alice');
    await _select(tester, ['alice']);

    await tester.tap(find.byTooltip('Unsubscribe'));
    await pumpUntilGone(tester, _row('alice'));
    expect(_row('bob'), findsOneWidget, reason: 'The other account should stay');

    await pumpUntilFound(tester, find.text('Undo'));
    // Lets the snack bar slide in, so that the tap lands on it
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Undo'));
    await pumpUntilFound(tester, _tag('alice', 'Friends'));
  });

  testWidgets('Should put the whole selection in a group partly holding it, then take it all out', (tester) async {
    final groupId = await tester.runAsync(() async {
      await follow([account('alice'), account('bob')]);
      return createGroup('Friends', [account('alice')]);
    });
    await _openPage(tester, 'alice');
    await pumpUntilFound(tester, _tag('alice', 'Friends'));
    await _addToGroups(tester, ['alice', 'bob']);
    final choice = find.widgetWithText(CheckboxListTile, 'Friends');
    bool? ticked() => tester.widget<CheckboxListTile>(choice).value;
    expect(ticked(), isNull, reason: 'A group holding part of the selection should be half ticked');

    await tester.tap(choice);
    await pumpUntil(tester, () => ticked() == true, reason: 'the group should get ticked');
    expect(await membersOf(tester, groupId!), {
      refOf(account('alice')),
      refOf(account('bob')),
    }, reason: 'Both selected accounts should be in the group');

    await tester.tap(choice);
    await pumpUntil(tester, () => ticked() == false, reason: 'the group should get unticked');
    expect(await membersOf(tester, groupId), isEmpty, reason: 'Tapping a group holding the selection should empty it');
  });

  testWidgets('Should hide only the selected accounts from the main feed, and offer to show them back', (tester) async {
    await tester.runAsync(() => follow([account('alice'), savedSearch('flutter')]));
    await _openPage(tester, 'alice');
    await _select(tester, ['alice', 'flutter']);

    await tester.tap(find.byTooltip('Hide from main feed'));
    await pumpUntilFound(tester, find.byTooltip('Show in main feed'));

    final subscriptions = context(tester).read<SubscriptionsModel>().state;
    expect(subscriptions.firstWhere((s) => s.name == 'alice').inFeed, isFalse, reason: 'The account should be hidden');
    expect(
      subscriptions.firstWhere((s) => s.name == 'flutter').inFeed,
      isTrue,
      reason: 'A saved search cannot be hidden from the main feed',
    );
  });

  testWidgets('Should clear the selection when a kind is chosen, and offer only kinds that have subscriptions', (
    tester,
  ) async {
    await tester.runAsync(() => follow([account('alice'), savedSearch('flutter')]));
    await _openPage(tester, 'alice');
    await _select(tester, ['alice']);

    await tester.tap(find.text('Searches 1'));
    await tester.pumpAndSettle();

    expect(find.byType(SelectionAppBar), findsNothing, reason: 'The selection could hold subscriptions now hidden');
    expect(_row('alice'), findsNothing, reason: 'Only the saved searches should be listed');
    expect(find.textContaining('Lists'), findsNothing, reason: 'There is no filter for kinds nobody follows');
  });

  testWidgets('Should show, while searching, the groups named like the search or holding a match', (tester) async {
    await tester.runAsync(() async {
      await follow([account('alice'), account('bob')]);
      await createGroup('Friends', [account('alice')]);
      await createGroup('Work', [account('bob')]);
      await createGroup('Alien films', []);
    });
    await _openPage(tester, 'alice', prefs: {optionSubscriptionGroupsCollapsed: true});
    await pumpUntilFound(tester, _tag('alice', 'Friends'));
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CompactSearchField), 'ali');
    await tester.pumpAndSettle();

    expect(_groupTile('Friends'), findsOneWidget, reason: 'The group of the matching account should show');
    expect(_groupTile('Alien films'), findsOneWidget, reason: 'A group whose name matches should show');
    expect(_groupTile('Work'), findsNothing, reason: 'A group without any match should hide');
  });

  testWidgets('Should list the followed communities under their own filter', (tester) async {
    await tester.runAsync(() => follow([account('alice'), followedCommunity('Flutter devs')]));
    await _openPage(tester, 'alice');

    await tester.tap(find.text('Communities 1'));
    await tester.pumpAndSettle();

    expect(_row('alice'), findsNothing, reason: 'Only the communities should be listed');
    expect(
      find.descendant(of: _row('Flutter devs'), matching: find.text('Community')),
      findsOneWidget,
      reason: 'The row should say it is a community, where an account shows its @name',
    );
  });

  testWidgets('Should put a followed community in a group', (tester) async {
    final groupId = await tester.runAsync(() async {
      await follow([followedCommunity('Flutter devs')]);
      return createGroup('Tech', []);
    });
    await _openPage(tester, 'Flutter devs');
    await _addToGroups(tester, ['Flutter devs']);
    final choice = find.widgetWithText(CheckboxListTile, 'Tech');

    await tester.tap(choice);
    await pumpUntil(tester, () => tester.widget<CheckboxListTile>(choice).value == true,
        reason: 'the group should get ticked');

    expect(await membersOf(tester, groupId!), {
      refOf(followedCommunity('Flutter devs')),
    }, reason: 'The community should be a member of the group, so that its posts show in the group feed');
  });
}

BuildContext context(WidgetTester tester) => tester.element(find.byType(SubscriptionsScreen));
