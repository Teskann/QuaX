import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/search/search_filter_fields.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/search/search_filters_screen.dart';

import '../ui/pump_app.dart';

/// What the filters page gave back once closed: null when closed without asking for the results.
class _Page {
  SearchFilters? result;
  bool closed = false;
}

Future<_Page> _openPage(WidgetTester tester, [SearchFilters initial = SearchFilters.none]) async {
  final page = _Page();
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await pumpInApp(
    tester,
    Builder(
      builder: (context) => TextButton(
        onPressed: () async {
          page.result = await SearchFiltersScreen.open(context, initial);
          page.closed = true;
        },
        child: const Text('Open the filters'),
      ),
    ),
  );
  await tester.tap(find.text('Open the filters'));
  await tester.pumpAndSettle();
  return page;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<SearchFilters> _showResults(WidgetTester tester, _Page page) async {
  await _tap(tester, find.text('Show results'));
  expect(page.closed, isTrue, reason: 'Show results should close the filters page');
  expect(page.result, isNotNull, reason: 'Show results should give the filters back');
  return page.result!;
}

Finder _field(String label) => find.ancestor(of: find.text(label), matching: find.byType(TextField)).first;

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pumpAndSettle();
}

Finder _accountsInput(String label) => find.descendant(
  of: find.ancestor(of: find.text(label), matching: find.byType(AccountsField)),
  matching: find.byType(TextField),
);

/// The summary under the title of a section, left out of what the section holds.
Finder _summary(String section, String summary) => find.descendant(
  of: find
      .descendant(
        of: find.ancestor(of: find.text(section), matching: find.byType(ExpansionTile)).first,
        matching: find.byType(ListTile),
      )
      .first,
  matching: find.text(summary),
);

void main() {
  // A tap that hits nothing would otherwise pass unnoticed
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);

  group('page', () {
    for (final (situation, navigationBar, keyboard) in [
      ('above the navigation bar', 48.0, 0.0),
      ('above the keyboard while it is open', 48.0, 300.0),
      ('above the navigation bar while the keyboard closes', 48.0, 20.0),
    ]) {
      testWidgets('Should keep Show results $situation', (tester) async {
        await _openPage(tester);
        final ratio = tester.view.devicePixelRatio;
        tester.view
          ..viewPadding = FakeViewPadding(bottom: navigationBar * ratio)
          ..padding = FakeViewPadding(bottom: (navigationBar - keyboard).clamp(0, navigationBar) * ratio)
          ..viewInsets = FakeViewPadding(bottom: keyboard * ratio);
        await tester.pumpAndSettle();
        final screenHeight = tester.view.physicalSize.height / ratio;
        final hidden = keyboard > navigationBar ? keyboard : navigationBar;

        expect(
          tester.getBottomLeft(find.widgetWithText(FilledButton, 'Show results')).dy,
          lessThanOrEqualTo(screenHeight - hidden),
          reason: 'Neither the keyboard nor the navigation bar should cover the button',
        );
      });
    }

    testWidgets('Should bring a field the keyboard would cover above Show results', (tester) async {
      await _openPage(tester);
      await _tap(tester, find.text('Minimum engagement'));
      final ratio = tester.view.devicePixelRatio;
      final screenHeight = tester.view.physicalSize.height / ratio;
      const keyboard = 360.0;
      final field = _field('Likes');
      expect(
        tester.getBottomLeft(field).dy,
        greaterThan(screenHeight - keyboard),
        reason: 'The field should start where the keyboard opens, or the test proves nothing',
      );

      await tester.tap(field);
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 2.625);
      await tester.pumpAndSettle();

      expect(
        tester.getBottomLeft(field).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.widgetWithText(FilledButton, 'Show results')).dy),
        reason: 'The field typed in should scroll above the button, which sits on the keyboard',
      );
    });

    testWidgets('Should give nothing back when closed', (tester) async {
      final page = await _openPage(tester, const SearchFilters(minFaves: 10));
      await _tap(tester, find.text('Clear all'));
      await _tap(tester, find.byIcon(Icons.close));

      expect(page.closed, isTrue, reason: 'The close button should close the page');
      expect(page.result, isNull, reason: 'Closing should cancel every change made in the page');
    });

    testWidgets('Should give the filters back untouched when nothing was changed', (tester) async {
      const initial = SearchFilters(fromAccounts: ['FlutterDev'], media: MediaFilter.videos, minFaves: 10);
      final page = await _openPage(tester, initial);
      final result = await _showResults(tester, page);

      expect(result.toOperators('en'), initial.toOperators('en'), reason: 'Opening the page should change nothing');
    });

    testWidgets('Should drop every filter and empty every field with Clear all', (tester) async {
      final page = await _openPage(
        tester,
        SearchFilters(
          language: LanguageChoice.mine,
          anyWords: const ['flutter', 'dart'],
          fromAccounts: const ['FlutterDev'],
          replies: ContentFilter.exclude,
          minFaves: 10,
          since: DateTime(2025, 1, 1),
        ),
      );
      await _tap(tester, find.text('Words'));
      await _tap(tester, find.text('Clear all'));

      expect(find.text('flutter dart'), findsNothing, reason: 'Clear all should empty the text fields too');
      final result = await _showResults(tester, page);
      expect(result.active, isEmpty, reason: 'Clear all should drop every filter');
    });

    testWidgets('Should open on the language only, every other section folded with its summary', (tester) async {
      await _openPage(tester, const SearchFilters(fromAccounts: ['FlutterDev'], links: ContentFilter.only));

      expect(find.text('My language'), findsOneWidget, reason: 'The language section should be open');
      expect(find.text('Any of these words'), findsNothing, reason: 'The words section should be folded');
      expect(find.text('From these accounts'), findsNothing, reason: 'The accounts section should be folded');
      expect(_summary('Words', 'No filter'), findsOneWidget, reason: 'A section without filter should say so');
      expect(_summary('Accounts', 'From @FlutterDev'), findsOneWidget, reason: 'A section should sum up its filters');
      expect(_summary('Content', 'Links only'), findsOneWidget, reason: 'A section should sum up its filters');
      expect(_summary('Date range', 'No filter'), findsOneWidget, reason: 'A section without filter should say so');
    });

    testWidgets('Should fold and unfold a section', (tester) async {
      await _openPage(tester);
      await _tap(tester, find.text('Words'));
      expect(find.text('Any of these words'), findsOneWidget, reason: 'Tapping a folded section should open it');

      await _tap(tester, find.text('Words'));
      expect(find.text('Any of these words'), findsNothing, reason: 'Tapping an open section should fold it');
    });
  });

  group('language', () {
    testWidgets('Should filter on every language, my language or another one', (tester) async {
      final page = await _openPage(tester);
      expect(_summary('Language', 'All languages'), findsOneWidget, reason: 'No language is filtered at first');

      await _tap(tester, find.text('My language'));
      expect(
        find.text('Follows the app language, currently English'),
        findsOneWidget,
        reason: 'My language should say which language it stands for',
      );
      expect(_summary('Language', 'In my language (English)'), findsOneWidget, reason: 'The summary should follow');
      expect(find.byType(DropdownMenu<String>), findsNothing, reason: 'The list is only for another language');

      await _tap(tester, find.text('Other'));
      expect(find.byType(DropdownMenu<String>), findsOneWidget, reason: 'Other should show the list of languages');
      expect(
        find.text('Follows the app language, currently English'),
        findsNothing,
        reason: 'The hint is only for my language',
      );

      await _tap(tester, find.byType(DropdownMenu<String>));
      await _tap(tester, find.text('Deutsch').last);
      expect(_summary('Language', 'Deutsch'), findsOneWidget, reason: 'The summary should name the language picked');

      final result = await _showResults(tester, page);
      expect(result.languageCode('en'), 'de', reason: 'The language picked in the list should be searched');
    });

    testWidgets('Should search in the app language with my language', (tester) async {
      final page = await _openPage(tester);
      await _tap(tester, find.text('My language'));
      final result = await _showResults(tester, page);

      expect(result.toOperators('en'), ['lang:en'], reason: 'My language should be the language of the app');
    });

    testWidgets('Should stop filtering on a language with All', (tester) async {
      final page = await _openPage(tester, const SearchFilters(language: LanguageChoice.other, otherLanguage: 'fr'));
      await _tap(tester, find.text('All').first);
      final result = await _showResults(tester, page);

      expect(result.languageCode('en'), isNull, reason: 'All should search every language');
    });
  });

  group('words', () {
    testWidgets('Should read each field of the words section', (tester) async {
      final page = await _openPage(tester);
      await _tap(tester, find.text('Words'));
      await _type(tester, 'Any of these words', 'flutter  dart');
      await _type(tester, 'None of these words', '-kotlin java');
      await _type(tester, 'Hashtags', '#Flutter Dart');

      expect(
        _summary('Words', 'Any of: flutter, dart, Without “kotlin”, Without “java”, #Flutter, #Dart'),
        findsOneWidget,
        reason: 'The summary should list the words typed',
      );
      final result = await _showResults(tester, page);
      expect(result.anyWords, ['flutter', 'dart'], reason: 'Words are split on spaces, however many');
      expect(result.noneWords, ['kotlin', 'java'], reason: 'A typed minus should not end up doubled');
      expect(result.hashtags, ['Flutter', 'Dart'], reason: 'A typed hash should not end up doubled');
    });

    testWidgets('Should show the words already set', (tester) async {
      await _openPage(tester, const SearchFilters(anyWords: ['a', 'b'], hashtags: ['c']));
      await _tap(tester, find.text('Words'));

      expect(find.widgetWithText(TextField, 'a b'), findsOneWidget, reason: 'The words set should be shown');
      expect(find.widgetWithText(TextField, 'c'), findsOneWidget, reason: 'The hashtags set should be shown');
    });

    testWidgets('Should drop a filter whose field is emptied', (tester) async {
      final page = await _openPage(tester, const SearchFilters(anyWords: ['flutter', 'dart']));
      await _tap(tester, find.text('Words'));
      await _type(tester, 'Any of these words', '');
      final result = await _showResults(tester, page);

      expect(result.active, isEmpty, reason: 'An empty field should not filter anything');
    });
  });

  group('accounts', () {
    for (final (key, label) in [
      ('fromAccounts', 'From these accounts'),
      ('toAccounts', 'In reply to'),
      ('mentions', 'Mentioning'),
    ]) {
      testWidgets('Should add the accounts typed in "$label" and remove the one whose chip is closed', (tester) async {
        final page = await _openPage(tester);
        await _tap(tester, find.text('Accounts'));
        await tester.enterText(_accountsInput(label), '@FlutterDev');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.enterText(_accountsInput(label), 'dart_lang ');
        await tester.enterText(_accountsInput(label), 'quax_tests,');
        await tester.pumpAndSettle();

        expect(find.widgetWithText(InputChip, '@FlutterDev'), findsOneWidget, reason: 'Enter should add the account');
        expect(find.widgetWithText(InputChip, '@dart_lang'), findsOneWidget, reason: 'A space should add the account');
        expect(find.widgetWithText(InputChip, '@quax_tests'), findsOneWidget, reason: 'A comma should add it too');

        await _tap(
          tester,
          find.descendant(of: find.widgetWithText(InputChip, '@dart_lang'), matching: find.byIcon(Icons.clear)),
        );
        final result = await _showResults(tester, page);
        final accounts = switch (key) {
          'fromAccounts' => result.fromAccounts,
          'toAccounts' => result.toAccounts,
          _ => result.mentions,
        };
        expect(accounts, ['FlutterDev', 'quax_tests'], reason: '"$label" should keep the accounts left, in order');
      });
    }

    testWidgets('Should stay in the accounts field after Enter, to type the next account', (tester) async {
      await _openPage(tester);
      await _tap(tester, find.text('Accounts'));
      await tester.enterText(_accountsInput('From these accounts'), 'FlutterDev');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(_accountsInput('From these accounts')).focusNode!.hasFocus,
        isTrue,
        reason: 'Enter should add the account and leave the keyboard open for the next one',
      );
    });

    testWidgets('Should neither add an account twice nor something that is not an account', (tester) async {
      final page = await _openPage(tester, const SearchFilters(fromAccounts: ['FlutterDev']));
      await _tap(tester, find.text('Accounts'));
      await tester.enterText(_accountsInput('From these accounts'), 'FlutterDev');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.enterText(_accountsInput('From these accounts'), 'not an account!');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      final result = await _showResults(tester, page);

      expect(result.fromAccounts, ['FlutterDev'], reason: 'A duplicate or an invalid name should be left out');
    });

    testWidgets('Should add the account being typed when tapping elsewhere', (tester) async {
      final page = await _openPage(tester);
      await _tap(tester, find.text('Accounts'));
      await tester.enterText(_accountsInput('Mentioning'), 'FlutterDev');
      await _tap(tester, find.text('Accounts'));
      final result = await _showResults(tester, page);

      expect(result.mentions, ['FlutterDev'], reason: 'An account left in the field should not be lost');
    });
  });

  group('content', () {
    for (final (label, index, expected) in [
      ('Only', 0, 'filter:replies'),
      ('Exclude', 0, '-filter:replies'),
      ('Only', 1, 'filter:links'),
      ('Exclude', 1, '-filter:links'),
    ]) {
      testWidgets('Should write $expected for $label', (tester) async {
        final page = await _openPage(tester);
        await _tap(tester, find.text('Content'));
        await _tap(tester, find.text(label).at(index));
        final result = await _showResults(tester, page);

        expect(result.toOperators('en'), [expected], reason: 'Each choice should write its own operator');
      });
    }

    testWidgets('Should go back to every reply and link with Include', (tester) async {
      final page = await _openPage(
        tester,
        const SearchFilters(replies: ContentFilter.only, links: ContentFilter.exclude),
      );
      await _tap(tester, find.text('Content'));
      await _tap(tester, find.text('Include').at(0));
      await _tap(tester, find.text('Include').at(1));
      final result = await _showResults(tester, page);

      expect(result.active, isEmpty, reason: 'Include should stop filtering');
    });

    for (final (label, expected) in [('Images', 'filter:images'), ('Videos', 'filter:videos')]) {
      testWidgets('Should write $expected for $label and nothing for All', (tester) async {
        final page = await _openPage(tester);
        await _tap(tester, find.text('Content'));
        await _tap(tester, find.text(label).last);
        expect(_summary('Content', label), findsOneWidget, reason: 'The summary should name the media');
        final result = await _showResults(tester, page);
        expect(result.toOperators('en'), [expected], reason: '$label should keep the posts with that media');

        final again = await _openPage(tester, result);
        await _tap(tester, find.text('Content'));
        await _tap(tester, find.text('All').last);
        expect((await _showResults(tester, again)).active, isEmpty, reason: 'All should stop filtering the media');
      });
    }

    testWidgets('Should include the reposts with the switch', (tester) async {
      final page = await _openPage(tester);
      await _tap(tester, find.text('Content'));
      await _tap(tester, find.byType(Switch));
      expect(_summary('Content', 'With reposts'), findsOneWidget, reason: 'The summary should mention the reposts');
      final result = await _showResults(tester, page);

      expect(result.toOperators('en'), ['include:nativeretweets'], reason: 'The switch should add the reposts');
    });
  });

  group('engagement', () {
    testWidgets('Should read the three minimums', (tester) async {
      final page = await _openPage(tester);
      await _tap(tester, find.text('Minimum engagement'));
      await _type(tester, 'Replies', '5');
      await _type(tester, 'Likes', ' 50 ');
      await _type(tester, 'Reposts', '10');

      expect(
        _summary('Minimum engagement', 'At least 5 replies, At least 50 likes, At least 10 reposts'),
        findsOneWidget,
        reason: 'The summary should list the minimums',
      );
      final result = await _showResults(tester, page);
      expect(result.toOperators('en'), [
        'min_replies:5',
        'min_faves:50',
        'min_retweets:10',
      ], reason: 'Each minimum should write its operator');
    });

    testWidgets('Should drop a minimum that is emptied or is not a number', (tester) async {
      final page = await _openPage(tester, const SearchFilters(minReplies: 5, minFaves: 50));
      await _tap(tester, find.text('Minimum engagement'));
      expect(find.widgetWithText(TextField, '5'), findsOneWidget, reason: 'The minimums set should be shown');
      await _type(tester, 'Replies', '');
      await _type(tester, 'Likes', 'many');
      final result = await _showResults(tester, page);

      expect(result.active, isEmpty, reason: 'Only a number should filter');
    });
  });

  group('date range', () {
    testWidgets('Should pick both dates from the calendar', (tester) async {
      final page = await _openPage(tester);
      await _tap(tester, find.text('Date range'));
      await _tap(tester, find.text('Since'));
      await _tap(tester, find.byIcon(Icons.edit_outlined));
      await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '01/01/2025');
      await _tap(tester, find.text('OK'));
      await _tap(tester, find.text('Until'));
      await _tap(tester, find.byIcon(Icons.edit_outlined));
      await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '07/01/2025');
      await _tap(tester, find.text('OK'));

      expect(find.text('1/1/2025'), findsOneWidget, reason: 'The date picked should be shown in its field');
      expect(
        _summary('Date range', 'Since Jan 1, 2025, Until Jul 1, 2025'),
        findsOneWidget,
        reason: 'The summary should give both dates',
      );
      final result = await _showResults(tester, page);
      expect(result.toOperators('en'), ['since:2025-01-01', 'until:2025-07-01'], reason: 'X takes dates as yyyy-mm-dd');
    });

    testWidgets('Should keep the date when the calendar is cancelled', (tester) async {
      final page = await _openPage(tester, SearchFilters(since: DateTime(2025, 1, 1)));
      await _tap(tester, find.text('Date range'));
      await _tap(tester, find.text('1/1/2025'));
      expect(find.byType(DatePickerDialog), findsOneWidget, reason: 'Tapping a date should open the calendar');
      await _tap(tester, find.text('Cancel'));
      final result = await _showResults(tester, page);

      expect(result.since, DateTime(2025, 1, 1), reason: 'Cancelling the calendar should change nothing');
    });

    testWidgets('Should clear a date with its clear button', (tester) async {
      final page = await _openPage(tester, SearchFilters(since: DateTime(2025, 1, 1), until: DateTime(2025, 7, 1)));
      await _tap(tester, find.text('Date range'));
      await _tap(tester, find.bySemanticsLabel('Clear').first);
      final result = await _showResults(tester, page);

      expect(result.since, isNull, reason: 'The clear button should drop its date');
      expect(result.until, DateTime(2025, 7, 1), reason: 'The other date should stay');
    });
  });
}
