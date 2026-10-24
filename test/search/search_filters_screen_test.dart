import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/search/search.dart';
import 'package:quax/search/search_filter_chips.dart';
import 'package:quax/search/search_filter_fields.dart';
import 'package:quax/search/search_filters_screen.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';

const _imagesQuery = 'from:FlutterDev filter:images';

/// The queries of the Latest tab, in the order they were sent.
List<String> _latestQueries(List<Uri> uris) => uris
    .map((uri) => jsonDecode(uri.queryParameters['variables']!) as Map<String, dynamic>)
    .where((variables) => variables['product'] == 'Latest')
    .map((variables) => variables['rawQuery'] as String)
    .toList();

String _barText(WidgetTester tester) => tester.widget<SearchBar>(find.byType(SearchBar)).controller!.text;

Future<List<Uri>> _openSearch(WidgetTester tester, {String query = ''}) async {
  final uris = <Uri>[];
  await pumpScreen(
    tester,
    const ResultsScreen(),
    arguments: SearchArguments(SearchTab.latest, query: query),
    fixtures: {'SearchTimeline': fixture('SearchTimeline', 'from-flutterdev-filter-images', unstable: true)},
    requestedUris: uris,
  );
  return uris;
}

Future<void> _openFiltersPage(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.tune));
  await tester.pumpAndSettle();
}

Future<void> _showResults(WidgetTester tester) async {
  await tester.tap(find.text('Show results'));
  await tester.pump(const Duration(seconds: 1));
  await pumpUntilLoaded(tester);
}

Future<void> _pumpChipsAnimation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUpAll(() {
    HttpOverrides.global = FakeImageHttpOverrides();
    // A tap that hits nothing would otherwise pass unnoticed
    WidgetController.hitTestWarningShouldBeFatal = true;
  });

  testWidgets('Should send X the query the website sends for the same filters', (tester) async {
    final recorded = fixture('SearchTimeline', 'from-flutterdev-filter-images', unstable: true);
    final uris = await _openSearch(tester, query: _imagesQuery);

    expect(
      _latestQueries(uris).first,
      Uri.parse(recorded.sourceUrl).queryParameters['q'],
      reason: 'The filters should reach X written as the website writes them',
    );
    expect(_barText(tester), isEmpty, reason: 'The operators should not be shown in the search bar');
    expect(find.text('From @FlutterDev'), findsOneWidget, reason: 'from: should be shown as a chip');
    expect(find.text('Images'), findsOneWidget, reason: 'filter:images should be shown as a chip');
    expect(find.byType(TweetTile), findsWidgets, reason: 'The posts X found should be listed');
  });

  testWidgets('Should move the operators typed in the bar to the filters once the search is sent', (tester) async {
    final uris = await _openSearch(tester);
    await tester.enterText(find.byType(SearchBar), 'flutter from:FlutterDev -filter:replies');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntilLoaded(tester);

    expect(_barText(tester), 'flutter', reason: 'Only the words should stay in the bar');
    expect(find.text('From @FlutterDev'), findsOneWidget, reason: 'The account should become a chip');
    expect(find.text('Without replies'), findsOneWidget, reason: 'The replies filter should become a chip');
    expect(find.text('2'), findsOneWidget, reason: 'The filters button should count the two filters');
    expect(
      _latestQueries(uris).last,
      'flutter from:FlutterDev -filter:replies',
      reason: 'Moving the operators should not change what is searched',
    );
  });

  testWidgets('Should search again without the filter whose chip was closed', (tester) async {
    final uris = await _openSearch(tester, query: _imagesQuery);
    await tester.tap(
      find.descendant(of: find.widgetWithText(InputChip, 'From @FlutterDev'), matching: find.byIcon(Icons.clear)),
    );
    await pumpUntilLoaded(tester);

    expect(find.text('From @FlutterDev'), findsNothing, reason: 'The closed chip should disappear');
    expect(find.text('Images'), findsOneWidget, reason: 'The other chips should stay');
    expect(_latestQueries(uris).last, 'filter:images', reason: 'The search should no longer ask for the account');
  });

  testWidgets('Should apply the filters picked in the filters page', (tester) async {
    final uris = await _openSearch(tester, query: 'flutter');
    await _openFiltersPage(tester);
    expect(find.byType(SearchFiltersScreen), findsOneWidget, reason: 'The filters button should open the page');

    await tester.tap(find.text('Content'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exclude').first);
    await tester.pumpAndSettle();
    expect(find.text('Without replies'), findsOneWidget, reason: 'The section should sum up its filter');
    await _showResults(tester);

    expect(find.byType(SearchFiltersScreen), findsNothing, reason: 'Show results should close the page');
    expect(find.widgetWithText(InputChip, 'Without replies'), findsOneWidget, reason: 'The filter should be a chip');
    expect(_latestQueries(uris).last, 'flutter -filter:replies', reason: 'The filter should be searched');
  });

  testWidgets('Should search in the app language when My language is picked', (tester) async {
    final uris = await _openSearch(tester, query: 'flutter');
    await _openFiltersPage(tester);
    await tester.tap(find.text('My language'));
    await tester.pumpAndSettle();

    expect(
      find.text('Follows the app language, currently English'),
      findsOneWidget,
      reason: 'The page should say which language My language stands for',
    );
    expect(find.byType(DropdownMenu<String>), findsNothing, reason: 'The language list is only for Other');
    await _showResults(tester);

    expect(_latestQueries(uris).last, 'flutter lang:en', reason: 'My language should be the language of the app');
  });

  testWidgets('Should show the language list only once Other is picked', (tester) async {
    await _openSearch(tester, query: 'flutter lang:de');
    await _openFiltersPage(tester);

    expect(find.byType(DropdownMenu<String>), findsOneWidget, reason: 'A language other than the app one is Other');
    expect(find.text('Deutsch'), findsWidgets, reason: 'The language should be named in its own language');
  });

  testWidgets('Should drop every filter with Clear all', (tester) async {
    final uris = await _openSearch(tester, query: _imagesQuery);
    await _openFiltersPage(tester);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await _showResults(tester);

    expect(find.byType(InputChip), findsNothing, reason: 'No chip should be left');
    expect(_latestQueries(uris), isNot(contains('')), reason: 'An empty search should not be sent to X');
  });

  testWidgets('Should give the filters back untouched when the page is closed', (tester) async {
    final uris = await _openSearch(tester, query: _imagesQuery);
    await _openFiltersPage(tester);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump(const Duration(seconds: 1));
    await pumpUntilLoaded(tester);

    expect(find.widgetWithText(InputChip, 'Images'), findsOneWidget, reason: 'Closing should cancel the changes');
    expect(_latestQueries(uris).toSet(), {_imagesQuery}, reason: 'Closing should not search again');
  });

  testWidgets('Should only show the hint of an accounts field that has accounts or is being typed in', (tester) async {
    await _openSearch(tester, query: _imagesQuery);
    await _openFiltersPage(tester);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    expect(
      find.text('Add an account'),
      findsOneWidget,
      reason: 'An empty field shows its label alone, the hint would be drawn over it',
    );

    await tester.tap(_accountsInput('Mentioning'));
    await tester.pumpAndSettle();
    expect(find.text('Add an account'), findsNWidgets(2), reason: 'A focused field should show its hint');
  });

  testWidgets('Should paint the count of filters in the color of the theme', (tester) async {
    await _openSearch(tester, query: _imagesQuery);
    final badge = tester.widget<Badge>(find.byType(Badge));
    final colors = Theme.of(tester.element(find.byType(Badge))).colorScheme;

    expect(badge.backgroundColor, colors.primary, reason: 'The count is not an error, it should not be red');
    expect(badge.textColor, colors.onPrimary, reason: 'The count should stay readable on the theme color');
  });

  testWidgets('Should line the chips up from the start of the screen', (tester) async {
    await _openSearch(tester, query: 'filter:images');

    expect(
      tester.getTopLeft(find.widgetWithText(InputChip, 'Images')).dx,
      lessThan(16),
      reason: 'A single chip should start at the left edge, not be centered',
    );
  });

  testWidgets('Should build in the filters page the combined search recorded from the website', (tester) async {
    final recorded = fixture(
      'SearchTimeline',
      'dart-from-flutterdev-or-from-dart-lang-lang-en-filter-replies-filter-links-since-2025-01-01',
      unstable: true,
    );
    final uris = await _openSearch(tester, query: 'dart');
    await _openFiltersPage(tester);

    await _tapInPage(tester, find.text('My language'));
    await _tapInPage(tester, find.text('Accounts'));
    await _addAccount(tester, 'From these accounts', 'FlutterDev');
    await _addAccount(tester, 'From these accounts', '@dart_lang');
    expect(find.text('@dart_lang'), findsOneWidget, reason: 'A typed account should become a chip, without its @');
    await _tapInPage(tester, find.text('Content'));
    await _tapInPage(tester, find.text('Exclude').first);
    await _tapInPage(tester, find.text('Only').at(1));
    await _tapInPage(tester, find.text('Date range'));
    await _pickDate(tester, 'Since', '01/01/2025');

    expect(
      find.text('From @FlutterDev, From @dart_lang'),
      findsOneWidget,
      reason: 'A closed section should sum up its filters',
    );
    await _showResults(tester);

    expect(
      _latestQueries(uris).last,
      Uri.parse(recorded.sourceUrl).queryParameters['q'],
      reason: 'The filters page should write the very query the website sent for the same filters',
    );
    expect(_barText(tester), 'dart', reason: 'The words should stay in the bar');
    for (final chip in ['My language', 'From @FlutterDev', 'From @dart_lang', 'Without replies', 'Links only']) {
      expect(find.widgetWithText(InputChip, chip), findsOneWidget, reason: 'The filter "$chip" should be a chip');
    }
  });

  testWidgets('Should send the recorded query of each content filter picked one after the other', (tester) async {
    final uris = await _openSearch(tester, query: _imagesQuery);
    final steps = {'Videos': 'from:FlutterDev filter:videos', 'All': 'from:FlutterDev'};
    for (final MapEntry(key: media, value: query) in steps.entries) {
      await _openFiltersPage(tester);
      await _tapInPage(tester, find.text('Content'));
      await _tapInPage(tester, find.text(media).last);
      await _showResults(tester);
      expect(_latestQueries(uris).last, query, reason: 'Picking $media should change the media filter only');
    }

    final contentSteps = [
      (label: 'Only', index: 0, query: 'from:FlutterDev filter:replies'),
      (label: 'Include', index: 0, query: 'from:FlutterDev'),
      (label: 'Exclude', index: 1, query: 'from:FlutterDev -filter:links'),
      (label: 'Only', index: 1, query: 'from:FlutterDev filter:links'),
    ];
    for (final step in contentSteps) {
      await _openFiltersPage(tester);
      await _tapInPage(tester, find.text('Content'));
      await _tapInPage(tester, find.text(step.label).at(step.index));
      await _showResults(tester);
      expect(_latestQueries(uris).last, step.query, reason: 'Each content filter should write its own operator');
    }
    final recorded = fixturesOf('SearchTimeline').map((f) => Uri.parse(f.sourceUrl).queryParameters['q']).toSet();
    expect(
      _latestQueries(uris).toSet().difference({'from:FlutterDev'}).every(recorded.contains),
      isTrue,
      reason: 'Each filtered query sent should be one the website was recorded sending',
    );
  });

  testWidgets('Should keep a trend of several words in the bar, without a filter', (tester) async {
    final uris = await _openSearch(tester, query: '"Champions League"');

    expect(_barText(tester), '"Champions League"', reason: 'A trend is what the user searches for, not a filter');
    expect(find.byType(InputChip), findsNothing, reason: 'Opening a trend should not set any filter');
    expect(_latestQueries(uris).first, '"Champions League"', reason: 'The trend should be searched as X gave it');
  });

  testWidgets('Should hide the chips while the results scroll down and show them when they scroll up', (tester) async {
    await _openSearch(tester, query: _imagesQuery);
    final chip = find.text('Images').hitTestable();

    await tester.drag(find.byType(TabBarView), const Offset(0, -300));
    await _pumpChipsAnimation(tester);
    expect(chip, findsNothing, reason: 'The chips should make room for the results scrolled down');

    await tester.drag(find.byType(TabBarView), const Offset(0, 100));
    await _pumpChipsAnimation(tester);
    expect(chip, findsOneWidget, reason: 'The chips should come back when the results scroll up');
  });

  testWidgets('Should move every recorded operator typed in the bar to the filters page', (tester) async {
    await _openSearch(tester);
    await tester.enterText(
      find.byType(SearchBar),
      '"hot reload" (flutter OR dart) -kotlin (#Flutter OR #Dart) to:FlutterDev min_replies:5 min_faves:50 '
      'min_retweets:10 since:2025-01-01 until:2025-07-01 lang:fr',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntilLoaded(tester);

    expect(
      _barText(tester),
      '"hot reload"',
      reason: 'The phrase typed is what the user searches for, it should stay in the bar',
    );
    await _openFiltersPage(tester);
    final summaries = {
      'Language': 'français',
      'Words': 'Any of: flutter, dart, Without “kotlin”, #Flutter, #Dart',
      'Accounts': 'Replying to @FlutterDev',
      'Minimum engagement': 'At least 5 replies, At least 50 likes, At least 10 reposts',
      'Date range': 'Since Jan 1, 2025, Until Jul 1, 2025',
    };
    for (final MapEntry(key: section, value: summary) in summaries.entries) {
      await tester.ensureVisible(find.text(section).first);
      expect(find.text(summary), findsWidgets, reason: 'The $section section should sum up what was typed');
    }
  });

  testWidgets('Should search with the operators typed while they are being typed, without moving them', (tester) async {
    final uris = await _openSearch(tester);
    await tester.enterText(find.byType(SearchBar), 'flutter from:FlutterDev');
    await tester.pump(const Duration(milliseconds: 800));
    await pumpUntilLoaded(tester);

    expect(_latestQueries(uris).last, 'flutter from:FlutterDev', reason: 'A pause in the typing should search');
    expect(_barText(tester), 'flutter from:FlutterDev', reason: 'The operators only move once the search is sent');
    expect(find.byType(InputChip), findsNothing, reason: 'No chip should appear while typing');
  });

  testWidgets('Should add the operators typed to the filters already set', (tester) async {
    final uris = await _openSearch(tester, query: 'from:FlutterDev');
    await tester.enterText(find.byType(SearchBar), 'from:dart_lang lang:en');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpUntilLoaded(tester);

    expect(find.widgetWithText(InputChip, 'From @FlutterDev'), findsOneWidget, reason: 'The account set should stay');
    expect(find.widgetWithText(InputChip, 'From @dart_lang'), findsOneWidget, reason: 'The typed account should join');
    expect(find.widgetWithText(InputChip, 'My language'), findsOneWidget, reason: 'lang:en is the app language');
    expect(
      _latestQueries(uris).last,
      '(from:FlutterDev OR from:dart_lang) lang:en',
      reason: 'Both accounts should be searched',
    );
  });

  testWidgets('Should move the operators typed to the filters before opening the filters page', (tester) async {
    await _openSearch(tester);
    await tester.enterText(find.byType(SearchBar), 'flutter min_faves:50');
    await _openFiltersPage(tester);

    expect(find.text('At least 50 likes'), findsOneWidget, reason: 'The page should show what was typed');
    await tester.tap(find.byIcon(Icons.close));
    await pumpUntilLoaded(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(_barText(tester), 'flutter', reason: 'The operator should have left the bar');
    expect(find.widgetWithText(InputChip, 'At least 50 likes'), findsOneWidget, reason: 'It should be a chip');
  });

  testWidgets('Should open the filters page when a chip is tapped', (tester) async {
    await _openSearch(tester, query: _imagesQuery);
    await tester.tap(find.text('Images'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchFiltersScreen), findsOneWidget, reason: 'A chip should lead to the filters page');
  });

  testWidgets('Should follow the whole search, its filters included', (tester) async {
    await _openSearch(tester, query: 'flutter $_imagesQuery');
    expect(
      tester.widget<FollowButton>(find.byType(FollowButton)).user.id,
      'flutter $_imagesQuery',
      reason: 'A followed search should keep its filters',
    );

    await tester.tap(
      find.descendant(of: find.widgetWithText(InputChip, 'From @FlutterDev'), matching: find.byIcon(Icons.clear)),
    );
    await pumpUntilLoaded(tester);
    expect(
      tester.widget<FollowButton>(find.byType(FollowButton)).user.id,
      'flutter filter:images',
      reason: 'The followed search should follow the filters',
    );
  });

  testWidgets('Should apply the filters to every tab of posts, and search people with the words only', (tester) async {
    final semantics = tester.ensureSemantics();
    final uris = await _openSearch(tester, query: 'flutter $_imagesQuery');
    for (final tab in ['Top', 'Media', 'People']) {
      await tester.tap(find.bySemanticsLabel(RegExp('^$tab')));
      await tester.pump(const Duration(seconds: 1));
      await pumpUntilLoaded(tester);
    }
    final queries = {
      for (final variables in uris.map((uri) => jsonDecode(uri.queryParameters['variables']!) as Map<String, dynamic>))
        variables['product']: variables['rawQuery'],
    };

    for (final product in ['Top', 'Latest', 'Media']) {
      expect(queries[product], 'flutter $_imagesQuery', reason: 'The $product tab should search with the filters');
    }
    expect(queries['People'], 'flutter', reason: 'X ignores the filters when it searches accounts');
    semantics.dispose();
  });

  testWidgets('Should name each tab of the results', (tester) async {
    final semantics = tester.ensureSemantics();
    await _openSearch(tester);

    for (final tab in ['Top', 'Latest', 'Media', 'People']) {
      expect(find.bySemanticsLabel(RegExp('^$tab')), findsOneWidget, reason: 'TalkBack should read the $tab tab');
    }
    semantics.dispose();
  });

  testWidgets('Should hide the filters button badge and the chips row without any filter', (tester) async {
    await _openSearch(tester, query: 'flutter');

    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse, reason: 'No filter means no count');
    expect(find.byType(SearchFilterChips), findsNothing, reason: 'No filter means no chips row');
  });
}

Future<void> _tapInPage(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder _accountsInput(String field) => find.descendant(
  of: find.ancestor(of: find.text(field), matching: find.byType(AccountsField)),
  matching: find.byType(TextField),
);

Future<void> _addAccount(WidgetTester tester, String field, String account) async {
  final input = _accountsInput(field);
  await tester.ensureVisible(input);
  await tester.enterText(input, account);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Future<void> _pickDate(WidgetTester tester, String field, String typed) async {
  await _tapInPage(tester, find.text(field));
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), typed);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
