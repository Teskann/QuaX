import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/_x_topic_catalog.dart';
import 'package:quax/home/_x_topics.dart';
import 'package:quax/ui/x_icons.dart';

import 'x_pump.dart';

const _technologyQuery = '(technology OR tech OR gadgets OR software) min_faves:20 -filter:replies';

void main() {
  final created = <(String, String)>[];

  setUp(created.clear);

  Future<String> fakeCreate(String name, String query) async {
    created.add((name, query));
    return 'group-id';
  }

  Future<void> start(
    WidgetTester tester, {
    TrendNamesLoader? loadTrends,
    TopicTimelineCreator? createTimeline,
    List<String?>? popped,
  }) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpXApp(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final id = await Navigator.push(
                context,
                MaterialPageRoute<String>(
                  builder: (_) => XTopicsScreen(
                    loadTrends: loadTrends ?? () async => [],
                    createTimeline: createTimeline ?? fakeCreate,
                  ),
                ),
              );
              popped?.add(id);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester, String row) async {
    final button = find.descendant(of: find.widgetWithText(ListTile, row), matching: find.byIcon(XIcons.plus));
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  group('XTopicsScreen', () {
    testWidgets('Should list the curated topics with their localized names', (tester) async {
      await start(tester);

      expect(find.text('Add Timelines'), findsOneWidget, reason: 'The screen needs its title');
      expect(find.text('Topics'), findsOneWidget, reason: 'The curated topics have a section');
      final l10n = await L10n.load(const Locale('en'));
      for (final topic in xTopics) {
        expect(find.text(topic.name(l10n)), findsOneWidget, reason: '${topic.name(l10n)} should be offered');
      }
      expect(xTopics, hasLength(15), reason: 'The catalog holds fifteen topics');
      expect(find.byIcon(XIcons.plus), findsNWidgets(15), reason: 'Each topic has its "+" button');
    });

    testWidgets('Should offer a search field for a custom topic', (tester) async {
      await start(tester);

      expect(find.widgetWithText(TextField, 'Search for a topic'), findsOneWidget, reason: 'The field has its hint');
    });

    testWidgets('Should create the timeline of a topic with its query when tapping "+"', (tester) async {
      await start(tester);

      await add(tester, 'Technology');

      expect(created, [('Technology', _technologyQuery)], reason: 'The topic and its search should be used as is');
    });

    testWidgets('Should say the timeline was added and give the group id back', (tester) async {
      final popped = <String?>[];
      await start(tester, popped: popped);

      await add(tester, 'Music');

      expect(find.text('Timeline added'), findsOneWidget, reason: 'The user should be told');
      expect(find.text('Add Timelines'), findsNothing, reason: 'The screen should close');
      expect(popped, ['group-id'], reason: 'The caller should get the id of the group to select it');
    });

    testWidgets('Should create the timeline of a custom topic on submit', (tester) async {
      await start(tester);

      await tester.enterText(find.byType(TextField), '  flutter dev ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(created, [('flutter dev', 'flutter dev')], reason: 'The trimmed text is both the name and the search');
    });

    testWidgets('Should not create a timeline when the submitted text is blank', (tester) async {
      await start(tester);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(created, isEmpty, reason: 'There is no topic to search');
      expect(find.text('Add Timelines'), findsOneWidget, reason: 'The screen should stay open');
    });

    testWidgets('Should create only one timeline when "+" is tapped twice quickly', (tester) async {
      final answer = Completer<String>();
      await start(
        tester,
        createTimeline: (name, query) {
          created.add((name, query));
          return answer.future;
        },
      );

      final plus = find.descendant(of: find.widgetWithText(ListTile, 'News'), matching: find.byIcon(XIcons.plus));
      await tester.tap(plus);
      await tester.tap(plus);
      answer.complete('group-id');
      await tester.pumpAndSettle();

      expect(created, hasLength(1), reason: 'A second tap while adding should be ignored');
      expect(find.text('Add Timelines'), findsNothing, reason: 'The screen closes once, not twice');
    });
  });

  group('XTopicsScreen trending', () {
    testWidgets('Should show the trends, at most ten', (tester) async {
      await start(tester, loadTrends: () async => List.generate(12, (i) => '#trend$i'));

      expect(find.text('Trending'), findsOneWidget, reason: 'The trends have their section');
      expect(find.text('#trend0'), findsOneWidget, reason: 'The first trend should be shown');
      expect(find.text('#trend9'), findsOneWidget, reason: 'The tenth trend should be shown');
      expect(find.text('#trend10'), findsNothing, reason: 'Only ten trends are shown');
    });

    testWidgets('Should create the timeline of a trend with the trend as search', (tester) async {
      await start(tester, loadTrends: () async => ['#quax', 'Some words']);

      await add(tester, '#quax');

      expect(created, [('#quax', '#quax')], reason: 'A hashtag is searched as it is');
    });

    testWidgets('Should search a trend of several words as a phrase', (tester) async {
      await start(tester, loadTrends: () async => ['Some words']);

      await add(tester, 'Some words');

      expect(created, [('Some words', '"Some words"')], reason: 'The words should stay together');
    });

    testWidgets('Should hide the trends silently when they fail to load', (tester) async {
      await start(tester, loadTrends: () async => throw Exception('rate limited'));

      expect(find.text('Trending'), findsNothing, reason: 'No section without trends');
      expect(find.text('Topics'), findsOneWidget, reason: 'The curated topics are still there');
      expect(find.textContaining('Exception'), findsNothing, reason: 'The error is not shown');
    });

    testWidgets('Should hide the trending section when there is no trend', (tester) async {
      await start(tester, loadTrends: () async => []);

      expect(find.text('Trending'), findsNothing, reason: 'An empty section is useless');
    });
  });

  group('trendQuery', () {
    test('Should keep a single word or a hashtag as it is', () {
      expect(trendQuery('#quax'), '#quax', reason: 'A hashtag needs no quotes');
      expect(trendQuery('Quax'), 'Quax', reason: 'A single word needs no quotes');
    });

    test('Should quote several words', () {
      expect(trendQuery('New York'), '"New York"', reason: 'A phrase is searched as a whole');
    });
  });

  group('xTopics', () {
    test('Should keep the search operators in the query of every locale', () async {
      for (final locale in L10n.delegate.supportedLocales) {
        final l10n = await L10n.load(locale);
        for (final topic in xTopics) {
          final query = topic.query(l10n);
          final reason = '${locale.toLanguageTag()} ${topic.name(l10n)}: $query';
          expect(query, startsWith('('), reason: '$reason should group the keywords');
          expect(query, endsWith(') min_faves:20 -filter:replies'), reason: '$reason should keep the operators');
          expect(topic.name(l10n).trim(), isNotEmpty, reason: '$reason needs a name');
        }
      }
    });

    test('Should write the technology query as the specification says', () async {
      expect(xTopics[3].query(await L10n.load(const Locale('en'))), _technologyQuery, reason: 'English technology');
      expect(
        xTopics[3].query(await L10n.load(const Locale('pt'))),
        '(tecnologia OR tech OR gadgets OR software) min_faves:20 -filter:replies',
        reason: 'Portuguese technology keeps the operators and translates the keyword',
      );
    });
  });
}
