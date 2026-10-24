import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/community_screen.dart';
import 'package:quax/community/community_search_results.dart';
import 'package:quax/community/community_tile.dart';
import 'package:quax/constants.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_filters_button.dart';

import '../fixtures.dart';
import '../mock_x_client.dart';
import '../ui/fake_images.dart';
import 'pump_community.dart';

/// The recorded pages of the search, in the order the cursors chain them.
List<Fixture> _pagesInOrder() {
  final pages = fixturesOf('CommunitiesSearchQuery');
  final chain = <Fixture>[];
  String? cursor;
  while (true) {
    final next = pages.where((page) => page.variables['cursor'] == cursor).firstOrNull;
    if (next == null) return chain;
    chain.add(next);
    cursor = next.body['data']['communities_search_slice']['slice_info']['next_cursor'];
  }
}

String get _recordedQuery => _pagesInOrder().first.variables['query'];

Future<List<Route<dynamic>>> _search(WidgetTester tester, String query,
        {MockXClient? client, SearchTab tab = SearchTab.communities}) =>
    pumpRoute(
      tester,
      const ResultsScreen(),
      RouteSettings(name: routeSearch, arguments: SearchArguments(tab, query: query)),
      client: client,
    );

List<String> _answered(MockXClient client) =>
    client.answers.map((answer) => answer.fixture).nonNulls.where((file) => file.contains('CommunitiesSearchQuery')).toList();

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should list the communities X finds, in its order', (tester) async {
    await _search(tester, _recordedQuery);
    final firstPage = Twitter.parseCommunitiesSearch(_pagesInOrder().first.body).items;

    final shown = tester.widgetList<CommunityTile>(find.byType(CommunityTile)).map((tile) => tile.community.id).toList();
    expect(shown, isNotEmpty, reason: 'The Communities tab should list what X found');
    expect(shown.take(firstPage.length), firstPage.map((community) => community.id),
        reason: 'The communities should keep the order X gives');
    expect(find.text(firstPage.first.name), findsWidgets, reason: 'Each community shows its name');
  });

  testWidgets('Should load every recorded page of results by following their cursors', (tester) async {
    final client = mockOfX();
    await _search(tester, _recordedQuery, client: client);
    final pages = _pagesInOrder();

    await scrollDownUntil(tester, find.byType(CommunitySearchResults), () => _answered(client).length == pages.length);

    expect(pages.length, greaterThan(1), reason: 'The capture should hold several pages for this test to mean much');
    expect(_answered(client), pages.map((page) => page.path),
        reason: 'Each page should be asked with the cursor of the previous one, exactly as the website does');
  });

  testWidgets('Should search communities with the words only, without the operators of the filters', (tester) async {
    final client = mockOfX();
    await _search(tester, '$_recordedQuery lang:en min_faves:10', client: client);

    expect(_answered(client).first, _pagesInOrder().first.path,
        reason: 'The filters only apply to posts, so X should be asked for the communities of the words alone');
  });

  testWidgets('Should open a community when tapped', (tester) async {
    final pushed = await _search(tester, _recordedQuery);
    final first = tester.widget<CommunityTile>(find.byType(CommunityTile).first).community;

    await tester.tap(find.byType(CommunityTile).first);
    await pumpTransition(tester);

    expect(pushed.single.settings.name, routeCommunity, reason: 'A community found opens the community screen');
    expect((pushed.single.settings.arguments as CommunityScreenArguments).id, first.id,
        reason: 'The community opened should be the one tapped');
  });

  testWidgets('Should hide the filters, which only apply to posts, on the Communities tab', (tester) async {
    await _search(tester, _recordedQuery, tab: SearchTab.top);
    expect(find.byType(SearchFiltersButton), findsOneWidget, reason: 'The Top tab offers the filters');

    await tester.tap(find.byIcon(Icons.groups));
    await pumpTransition(tester);

    expect(find.byType(SearchFiltersButton), findsNothing,
        reason: 'The filters would change nothing to the communities found');
  });
}
