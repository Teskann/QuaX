import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_filters_screen.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'pump_trends.dart';

/// Opens the trends, with the results screen behind their search bar.
Future<List<Uri>> _openTrends(WidgetTester tester) async {
  final uris = <Uri>[];
  Twitter.client = FixtureTwitterClient(
    {'SearchTimeline': fixture('SearchTimeline', 'from-flutterdev-filter-images', unstable: true)},
    requestedUris: uris,
  );
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await pumpInApp(
    tester,
    withAppModels(Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => settings.name == routeSearch ? const ResultsScreen() : trendsScreenWithModels(),
      ),
    )),
    settle: false,
  );
  await pumpUntilLoaded(tester);
  return uris;
}

String _barText(WidgetTester tester) => tester.widget<SearchBar>(find.byType(SearchBar).last).controller!.text;

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
    // A tap that hits nothing would otherwise pass unnoticed
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  testWidgets('Should open the filters from the search bar of the trends, then the results with them', (tester) async {
    final uris = await _openTrends(tester);
    await tester.enterText(find.byType(SearchBar), 'flutter from:FlutterDev');
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchFiltersScreen), findsOneWidget, reason: 'The filters button should open the filters');
    expect(find.text('From @FlutterDev'), findsOneWidget, reason: 'The operators typed should be in the filters');
    await tester.tap(find.text('Show results'));
    await tester.pump(const Duration(seconds: 1));
    await pumpUntilLoaded(tester);

    expect(find.byType(ResultsScreen), findsOneWidget, reason: 'Show results should open the results');
    expect(_barText(tester), 'flutter', reason: 'Only the words should be in the bar of the results');
    expect(find.widgetWithText(InputChip, 'From @FlutterDev'), findsOneWidget, reason: 'The filter should be a chip');
    final searched = uris.map((uri) => jsonDecode(uri.queryParameters['variables']!)['rawQuery'] as String);
    expect(searched, contains('flutter from:FlutterDev'), reason: 'The results should be searched with the filters');
  });

  testWidgets('Should open the results without filters when the filters page is closed', (tester) async {
    await _openTrends(tester);
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(SearchFiltersScreen), findsNothing, reason: 'Closing should go back to the trends');
    expect(find.byType(ResultsScreen), findsNothing, reason: 'Closing the filters should not search');
  });
}
