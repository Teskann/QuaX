import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/lists/x_list.dart';
import 'package:quax/lists/x_list_screen.dart';
import 'package:quax/lists/x_list_tile.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_filters_button.dart';
import 'package:quax/ui/paged_results.dart';

import '../fixtures.dart';
import '../mock_x_client.dart';
import '../pump_route.dart';
import '../ui/fake_images.dart';
import 'pump_list.dart';

/// The recorded pages of the search of lists, in the order the cursors chain them.
List<Fixture> _pagesInOrder() =>
    chainPages(listSearchPages(), (page) => Twitter.parseListsSearch(page.body).nextCursor);

String get _recordedQuery => _pagesInOrder().first.variables['rawQuery'];

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should list the lists X finds, in its order', (tester) async {
    await pumpSearch(tester, _recordedQuery, SearchTab.lists);
    final firstPage = Twitter.parseListsSearch(_pagesInOrder().first.body).items;

    final shown = tester.widgetList<XListTile>(find.byType(XListTile)).map((tile) => tile.list.id).toList();
    expect(shown, isNotEmpty, reason: 'The Lists tab should list what X found');
    expect(
      shown,
      firstPage.map((list) => list.id).take(shown.length),
      reason: 'The lists should keep the order X gives',
    );
  });

  testWidgets('Should load every recorded page of results by following their cursors', (tester) async {
    final client = mockOfX();
    await pumpSearch(tester, _recordedQuery, SearchTab.lists, client: client);
    final pages = _pagesInOrder();
    final files = pages.map((page) => page.path).toSet();

    await scrollDownUntil(
      tester,
      find.byType(PagedResults<XList>),
      () => answeredFixtures(client, files).length == pages.length,
    );

    expect(pages.length, greaterThan(1), reason: 'The capture should hold several pages for this test to mean much');
    expect(
      answeredFixtures(client, files),
      pages.map((page) => page.path),
      reason: 'Each page should be asked with the cursor of the previous one, exactly as the website does',
    );
  });

  testWidgets('Should search lists with the words only, without the operators of the filters', (tester) async {
    final client = mockOfX();
    await pumpSearch(tester, '$_recordedQuery lang:en min_faves:10', SearchTab.lists, client: client);

    expect(
      answeredFixtures(client, {_pagesInOrder().first.path}),
      isNotEmpty,
      reason: 'The filters only apply to posts, so X should be asked for the lists of the words alone',
    );
  });

  testWidgets('Should open a list when tapped', (tester) async {
    final pushed = await pumpSearch(tester, _recordedQuery, SearchTab.lists);
    final first = tester.widget<XListTile>(find.byType(XListTile).first).list;

    await tester.tap(find.byType(XListTile).first);
    await pumpTransition(tester);

    expect(pushed.single.settings.name, routeList, reason: 'A list found opens the list screen');
    expect(
      (pushed.single.settings.arguments as XListScreenArguments).id,
      first.id,
      reason: 'The list opened should be the one tapped',
    );
  });

  testWidgets('Should hide the filters, which only apply to posts, on the Lists tab', (tester) async {
    await pumpSearch(tester, _recordedQuery, SearchTab.top);
    expect(find.byType(SearchFiltersButton), findsOneWidget, reason: 'The Top tab offers the filters');

    await tester.tap(find.byIcon(Icons.list_alt));
    await pumpTransition(tester);

    expect(find.byType(SearchFiltersButton), findsNothing, reason: 'The filters would not change the lists found');
  });
}
