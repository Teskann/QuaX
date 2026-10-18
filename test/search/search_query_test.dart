import 'package:flutter_test/flutter_test.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/search/search_model.dart';
import 'package:quax/search/search_query.dart';

const _appLanguage = 'fr';

SearchFilters _parsedFilters(String raw) => SearchQuery.parse(raw, _appLanguage).filters;

void main() {
  group('compose', () {
    test('Should send the bar text alone when no filter is set', () {
      expect(
        const SearchQuery('élections').compose(_appLanguage),
        'élections',
        reason: 'A plain search must reach X unchanged',
      );
    });

    test('Should write every filter in the order of X advanced search', () {
      final filters = SearchFilters(
        anyWords: const ['flutter', 'dart'],
        noneWords: const ['kotlin', 'java'],
        hashtags: const ['Flutter', 'Dart'],
        fromAccounts: const ['FlutterDev', 'dart_lang'],
        toAccounts: const ['quax_tests'],
        mentions: const ['quax_tests_2'],
        language: LanguageChoice.other,
        otherLanguage: 'en',
        replies: ContentFilter.exclude,
        links: ContentFilter.only,
        media: MediaFilter.images,
        reposts: true,
        minReplies: 5,
        minFaves: 50,
        minRetweets: 10,
        since: DateTime(2025, 1, 1),
        until: DateTime(2025, 7, 1),
      );

      expect(
        SearchQuery('news', filters).compose(_appLanguage),
        'news (flutter OR dart) -kotlin -java (#Flutter OR #Dart) (from:FlutterDev OR from:dart_lang) '
        'to:quax_tests @quax_tests_2 lang:en -filter:replies filter:links filter:images include:nativeretweets '
        'min_replies:5 min_faves:50 min_retweets:10 since:2025-01-01 until:2025-07-01',
        reason: 'Each filter should become the operator X documents for it',
      );
    });

    test('Should filter on the app language when the user picks their language', () {
      const filters = SearchFilters(language: LanguageChoice.mine, otherLanguage: 'de');
      expect(
        const SearchQuery('flutter', filters).compose('pt'),
        'flutter lang:pt',
        reason: 'My language should follow the language of the app, not the one picked in the list',
      );
    });

    test('Should not filter on a language when every language is allowed', () {
      const filters = SearchFilters(otherLanguage: 'de');
      expect(
        const SearchQuery('flutter', filters).compose(_appLanguage),
        'flutter',
        reason: 'The language list only matters once Other is picked',
      );
    });
  });

  group('parse', () {
    test('Should move the operators out of the bar and keep the words', () {
      final query = SearchQuery.parse('élections from:journal_ex lang:de -filter:replies', _appLanguage);

      expect(query.text, 'élections', reason: 'Only the words should stay in the bar');
      expect(query.filters.fromAccounts, ['journal_ex'], reason: 'from: should fill the accounts');
      expect(query.filters.language, LanguageChoice.other, reason: 'A language other than the app one is Other');
      expect(query.filters.otherLanguage, 'de', reason: 'The language code should be kept');
      expect(query.filters.replies, ContentFilter.exclude, reason: '-filter:replies should hide the replies');
    });

    test('Should read the app language as my language', () {
      expect(
        _parsedFilters('lang:fr').language,
        LanguageChoice.mine,
        reason: 'A saved search in the app language should stay on My language',
      );
    });

    test('Should read the groups of accounts, hashtags and words', () {
      final filters = _parsedFilters('(from:a OR from:b) (to:c OR to:d) (@e OR @f) (#g OR #h) (i OR j)');

      expect(filters.fromAccounts, ['a', 'b'], reason: 'A group of from: should fill the accounts');
      expect(filters.toAccounts, ['c', 'd'], reason: 'A group of to: should fill the replied accounts');
      expect(filters.mentions, ['e', 'f'], reason: 'A group of mentions should fill the mentions');
      expect(filters.hashtags, ['g', 'h'], reason: 'A group of hashtags should fill the hashtags');
      expect(filters.anyWords, ['i', 'j'], reason: 'A group of words should fill Any of these words');
    });

    test('Should read the counts and the dates', () {
      final filters = _parsedFilters('min_replies:5 min_faves:50 min_retweets:10 since:2025-01-01 until:2025-07-01');

      expect(filters.minReplies, 5, reason: 'min_replies: should be read');
      expect(filters.minFaves, 50, reason: 'min_faves: should be read');
      expect(filters.minRetweets, 10, reason: 'min_retweets: should be read');
      expect(filters.since, DateTime(2025, 1, 1), reason: 'since: should be read');
      expect(filters.until, DateTime(2025, 7, 1), reason: 'until: should be read');
    });

    test('Should leave in the bar what the filters page cannot show', () {
      const raw =
          'flutter #dart @FlutterDev near:Paris -from:spam (a OR from:b) min_faves:many since:2025-13-01 lang:FR';
      final query = SearchQuery.parse(raw, _appLanguage);

      expect(query.text, raw, reason: 'An unknown or malformed operator must reach X as the user typed it');
      expect(query.filters.active, isEmpty, reason: 'Nothing should be moved to the filters');
    });

    test('Should keep a quoted phrase in the bar, as a trend of several words sends it', () {
      final query = SearchQuery.parse('"Champions League" (goal OR but) -replay from:UEFA', _appLanguage);

      expect(query.text, '"Champions League"', reason: 'A phrase is what the user searches for, not a filter');
      expect(query.filters.anyWords, ['goal', 'but'], reason: 'A group of words should still be a filter');
      expect(query.filters.noneWords, ['replay'], reason: 'An excluded word should still be a filter');
      expect(query.filters.fromAccounts, ['UEFA'], reason: 'An operator should still be a filter');
    });

    test('Should give back the query it read', () {
      const queries = [
        'from:FlutterDev filter:images',
        'from:FlutterDev -filter:links',
        'flutter lang:fr',
        'from:FlutterDev since:2025-01-01 until:2025-07-01',
        'from:FlutterDev min_replies:5 min_faves:50 min_retweets:10',
        '"hot reload" (flutter OR dart) -kotlin',
        '(#Flutter OR #Dart) from:FlutterDev',
        'dart (from:FlutterDev OR from:dart_lang) lang:en -filter:replies filter:links since:2025-01-01',
      ];
      for (final raw in queries) {
        expect(
          SearchQuery.parse(raw, _appLanguage).compose(_appLanguage),
          raw,
          reason: 'Opening a saved search must not change what is sent to X',
        );
      }
    });
  });

  group('filters', () {
    test('Should add the typed filters to the ones already set', () {
      const current = SearchFilters(fromAccounts: ['a'], replies: ContentFilter.exclude, minFaves: 10);
      final merged = current.merge(_parsedFilters('from:b min_faves:20'));

      expect(merged.fromAccounts, ['a', 'b'], reason: 'A typed account should join the accounts already set');
      expect(merged.replies, ContentFilter.exclude, reason: 'A filter not typed should be kept');
      expect(merged.minFaves, 20, reason: 'A typed value should replace the one set');
    });

    test('Should remove only the chip that was closed', () {
      const filters = SearchFilters(fromAccounts: ['a', 'b'], minFaves: 10);
      final removed = filters.without(const FromFilter('a'));

      expect(removed.fromAccounts, ['b'], reason: 'The other account should stay');
      expect(removed.minFaves, 10, reason: 'The other filters should stay');
      expect(removed.without(const MinFavesFilter(10)).minFaves, isNull, reason: 'A count should be removable');
    });

    test('Should list one chip per account and per value', () {
      const filters = SearchFilters(fromAccounts: ['a', 'b'], language: LanguageChoice.mine, since: null);
      expect(filters.active.length, 3, reason: 'Two accounts and the language make three chips');
    });
  });

  group('every filter', () {
    final all = SearchFilters(
      anyWords: const ['a', 'b'],
      noneWords: const ['c'],
      hashtags: const ['d', 'dd'],
      fromAccounts: const ['e'],
      toAccounts: const ['f'],
      mentions: const ['g', 'gg'],
      language: LanguageChoice.other,
      otherLanguage: 'de',
      replies: ContentFilter.only,
      links: ContentFilter.exclude,
      media: MediaFilter.videos,
      reposts: true,
      minReplies: 1,
      minFaves: 2,
      minRetweets: 3,
      since: DateTime(2025, 1, 1),
      until: DateTime(2025, 7, 1),
    );

    test('Should remove each filter alone', () {
      final active = all.active;
      expect(active, hasLength(18), reason: 'Every value set should have its chip');
      for (final filter in active) {
        final left = all.without(filter).active;
        expect(left, hasLength(active.length - 1), reason: 'Removing ${filter.runtimeType} should remove one chip');
      }
    });

    test('Should read back every filter it wrote', () {
      final raw = SearchQuery('news', all).compose('fr');
      final read = SearchQuery.parse(raw, 'fr');

      expect(read.text, 'news', reason: 'Only the words should stay in the bar');
      expect(read.filters.toOperators('fr'), all.toOperators('fr'), reason: 'Every filter should survive the trip');
    });

    test('Should clear a count or a date through copyWith, and keep it when not asked', () {
      expect(all.copyWith(minFaves: () => null).minFaves, isNull, reason: 'A count should be clearable');
      expect(all.copyWith(since: () => null).since, isNull, reason: 'A date should be clearable');
      expect(all.copyWith(reposts: false).minFaves, 2, reason: 'What is not asked should be kept');
    });
  });

  group('operators', () {
    test('Should read the media and reposts operators', () {
      expect(_parsedFilters('filter:videos').media, MediaFilter.videos, reason: 'filter:videos should be read');
      expect(_parsedFilters('filter:images').media, MediaFilter.images, reason: 'filter:images should be read');
      expect(_parsedFilters('include:nativeretweets').reposts, isTrue, reason: 'Reposts should be read');
      expect(_parsedFilters('filter:links').links, ContentFilter.only, reason: 'filter:links should be read');
    });

    test('Should keep in the bar the operators the page cannot write', () {
      for (final raw in [
        '-filter:images',
        '-include:nativeretweets',
        'lang:',
        'from:',
        'min_faves:-1',
        'until:2025-1-1',
      ]) {
        expect(SearchQuery.parse(raw, 'fr').text, raw, reason: '$raw has no place in the filters page');
      }
    });

    test('Should read a single account written with or without its @', () {
      expect(_parsedFilters('from:@FlutterDev').fromAccounts, ['FlutterDev'], reason: 'The @ is not part of the name');
      expect(_parsedFilters('(@a OR @b)').mentions, ['a', 'b'], reason: 'A group of mentions should be read');
    });
  });

  group('store', () {
    test('Should replace the filters and remove one of them', () {
      final store = SearchFiltersModel();
      expect(store.state.active, isEmpty, reason: 'A search starts without filter');

      store.set(const SearchFilters(fromAccounts: ['a', 'b']));
      store.remove(const FromFilter('a'));
      expect(store.state.fromAccounts, ['b'], reason: 'Removing a chip should only drop its value');
    });
  });

  test('Should leave a single hashtag or mention in the bar, as X searches it like a word', () {
    final query = SearchQuery.parse('#Flutter @FlutterDev', 'fr');

    expect(query.text, '#Flutter @FlutterDev', reason: 'A single hashtag or mention is what the user searches for');
    expect(query.filters.active, isEmpty, reason: 'Only a group of them is a filter');
  });
}
