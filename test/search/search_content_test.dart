import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/search/search.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';

const _peopleTab = 3;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should show every tweet of the Latest tab', (tester) async {
    final chains = Twitter.parseSearchTimeline(fixture('SearchTimeline', 'quax').body).chains;
    await pumpChains(tester, chains);

    expect(tweetsOf(chains), isNotEmpty, reason: 'A search for a common word should find tweets');
    expectEveryTweetRendered(chains);
  });

  testWidgets('Should list the accounts of the People tab with their name and handle', (tester) async {
    final people = fixture('SearchTimeline', 'quax-677c03');
    await pumpScreen(tester, const ResultsScreen(),
        arguments: SearchArguments(_peopleTab, query: 'quax'), fixtures: {'SearchTimeline': people});

    expect(find.byType(ErrorCard), findsNothing, reason: 'The People tab should load without error');
    final tiles = tester.widgetList<UserTile>(find.byType(UserTile)).toList();
    expect(tiles, isNotEmpty, reason: 'The accounts found should be listed');
    expect(tiles.first.user.screenName, 'JaydenQuax', reason: 'The accounts should keep the order X gives');
    expect(find.text('Jayden Quax'), findsOneWidget, reason: 'Each account should show its display name');
    expect(find.text('@JaydenQuax'), findsOneWidget, reason: 'Each account should show its handle');
  });
}
