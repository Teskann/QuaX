import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/search/search_filter_chips.dart';
import 'package:quax/search/search_filter_fields.dart';
import 'package:quax/search/search_filter_labels.dart';
import 'package:quax/search/search_filters.dart';

import '../ui/pump_app.dart';

void main() {
  // A tap that hits nothing would otherwise pass unnoticed
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  group('labels', () {
    setUpAll(() async {
      await initializeDateFormatting('en');
      await L10n.load(const Locale('en'));
    });

    test('Should give each filter a label of its own', () {
      final labels = {
        const AnyWordsFilter(['flutter', 'dart']): 'Any of: flutter, dart',
        const NoneWordFilter('kotlin'): 'Without “kotlin”',
        const HashtagFilter('Flutter'): '#Flutter',
        const FromFilter('FlutterDev'): 'From @FlutterDev',
        const ToFilter('FlutterDev'): 'Replying to @FlutterDev',
        const MentionFilter('FlutterDev'): 'Mentioning @FlutterDev',
        const LanguageFilter(LanguageChoice.mine, 'de'): 'My language',
        const LanguageFilter(LanguageChoice.other, 'de'): 'Deutsch',
        const RepliesFilter(ContentFilter.only): 'Replies only',
        const RepliesFilter(ContentFilter.exclude): 'Without replies',
        const LinksFilter(ContentFilter.only): 'Links only',
        const LinksFilter(ContentFilter.exclude): 'Without links',
        const MediaTypeFilter(MediaFilter.images): 'Images',
        const MediaTypeFilter(MediaFilter.videos): 'Videos',
        const RepostsFilter(): 'With reposts',
        const MinRepliesFilter(1): 'At least 1 reply',
        const MinRepliesFilter(5): 'At least 5 replies',
        const MinFavesFilter(1): 'At least 1 like',
        const MinFavesFilter(50): 'At least 50 likes',
        const MinRetweetsFilter(1): 'At least 1 repost',
        const MinRetweetsFilter(10): 'At least 10 reposts',
        SinceFilter(DateTime(2025, 1, 1)): 'Since Jan 1, 2025',
        UntilFilter(DateTime(2025, 7, 1)): 'Until Jul 1, 2025',
      };
      for (final MapEntry(key: filter, value: label) in labels.entries) {
        expect(activeFilterLabel(L10n.current, filter), label, reason: '${filter.runtimeType} should read "$label"');
      }
    });

    test('Should name a language in its own language', () {
      expect(languageName('fr'), 'français', reason: 'A reader of a language knows its own name for it');
      expect(languageName('ja'), '日本語', reason: 'A reader of a language knows its own name for it');
      expect(languageName('xx'), 'xx', reason: 'An unknown code should still be shown');
    });

    test('Should name a language X can filter on for every code of the list', () {
      final unnamed = searchLanguages.where((code) => languageName(code) == code);
      expect(unnamed, isEmpty, reason: 'Every language of the list should be shown by its name, not its code');
    });

    test('Should give X the code of the app language', () {
      final previous = Intl.defaultLocale;
      addTearDown(() => Intl.defaultLocale = previous);

      Intl.defaultLocale = 'pt_BR';
      expect(appSearchLanguage(), 'pt', reason: 'X filters on the language, not the country');
      Intl.defaultLocale = 'nb_NO';
      expect(appSearchLanguage(), 'no', reason: 'X calls Norwegian Bokmål "no"');
      Intl.defaultLocale = 'zh_Hant';
      expect(appSearchLanguage(), 'zh', reason: 'X filters on the language, not the script');
    });
  });

  group('words', () {
    test('Should split the words typed, dropping a prefix typed with them', () {
      expect(splitWords('  flutter   dart '), ['flutter', 'dart'], reason: 'Spaces should only separate the words');
      expect(splitWords('#Flutter Dart', prefix: '#'), ['Flutter', 'Dart'], reason: 'The hash is written by the app');
      expect(splitWords('-', prefix: '-'), isEmpty, reason: 'A prefix alone is not a word');
    });
  });

  group('chips', () {
    Future<({List<ActiveFilter> removed, List<int> taps})> pumpChips(WidgetTester tester, SearchFilters filters) async {
      final removed = <ActiveFilter>[];
      final taps = <int>[];
      await pumpInApp(tester, SearchFilterChips(filters: filters, onRemoved: removed.add, onTap: () => taps.add(1)));
      return (removed: removed, taps: taps);
    }

    testWidgets('Should show one chip per filter, in the order of the query', (tester) async {
      await pumpChips(tester, const SearchFilters(fromAccounts: ['a', 'b'], minFaves: 10, media: MediaFilter.images));

      final labels = tester
          .widgetList<InputChip>(find.byType(InputChip))
          .map((chip) => (chip.label as Text).data)
          .toList();
      expect(labels, ['From @a', 'From @b', 'Images', 'At least 10 likes'], reason: 'Each value should be a chip');
    });

    testWidgets('Should give back the filter whose chip is closed', (tester) async {
      final calls = await pumpChips(tester, const SearchFilters(fromAccounts: ['a', 'b']));
      await tester.tap(
        find.descendant(of: find.widgetWithText(InputChip, 'From @b'), matching: find.byIcon(Icons.clear)),
      );

      expect(
        calls.removed.single,
        isA<FromFilter>().having((f) => f.account, 'account', 'b'),
        reason: 'Closing a chip should remove its own filter only',
      );
      expect(calls.taps, isEmpty, reason: 'Closing a chip should not open the filters');
    });

    testWidgets('Should keep the chips small, so they do not take room from the results', (tester) async {
      await pumpChips(tester, const SearchFilters(fromAccounts: ['a']));

      expect(
        tester.getSize(find.byType(InputChip)).height,
        lessThanOrEqualTo(32),
        reason: 'A chip should be compact',
      );
    });

    testWidgets('Should open the filters when a chip is tapped', (tester) async {
      final calls = await pumpChips(tester, const SearchFilters(fromAccounts: ['a']));
      await tester.tap(find.text('From @a'));

      expect(calls.taps, hasLength(1), reason: 'Tapping a chip should open the filters page');
      expect(calls.removed, isEmpty, reason: 'Tapping a chip should not remove it');
    });

    testWidgets('Should let the chips scroll sideways when they do not fit', (tester) async {
      await pumpChips(tester, SearchFilters(fromAccounts: List.generate(12, (i) => 'account_$i')));
      final last = find.text('From @account_11');

      expect(
        tester.getTopLeft(last).dx,
        greaterThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
        reason: 'The last chip should start off screen',
      );
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-5000, 0));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(last).dx,
        lessThan(tester.view.physicalSize.width / tester.view.devicePixelRatio),
        reason: 'Scrolling sideways should bring the last chip on screen',
      );
    });
  });
}
