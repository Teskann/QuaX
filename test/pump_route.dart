import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart' show AbstractTwitterClient;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/search/search.dart';

import '../tool/mock_x/fixture_map.dart';
import 'mock_x_client.dart';
import 'tweet/pump_tweets.dart';
import 'ui/pump_app.dart';

/// Answers every request with the recorded one it is identical to, so a wrong variable or cursor gets no answer.
MockXClient mockOfX() => MockXClient(FixtureMap.load(Directory('test/fixtures')));

/// Opens [screen] as the route [settings], answering its requests with [client] or the mock of X, then lets it load.
/// The returned list collects the screens pushed on top of it; a named route opens a blank page, so that what was
/// asked for can be checked.
Future<List<Route<dynamic>>> pumpRoute(
  WidgetTester tester,
  Widget screen,
  RouteSettings settings, {
  AbstractTwitterClient? client,
  Map<String, dynamic> prefs = const {},
}) async {
  Twitter.client = client ?? mockOfX();
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final pushed = <Route<dynamic>>[];
  await pumpInApp(
    tester,
    withAppModels(
      Navigator(
        observers: [_PushObserver(pushed)],
        onGenerateInitialRoutes: (_, _) => [MaterialPageRoute(settings: settings, builder: (_) => screen)],
        onGenerateRoute: (settings) => MaterialPageRoute(settings: settings, builder: (_) => const SizedBox()),
      ),
    ),
    settle: false,
    prefs: prefs,
  );
  await pumpUntilLoaded(tester);
  pushed.clear();
  return pushed;
}

class _PushObserver extends NavigatorObserver {
  _PushObserver(this.pushed);

  final List<Route<dynamic>> pushed;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route);
}

/// Lets a page transition or a tab change finish, which pumpAndSettle cannot wait for while videos spin.
Future<void> pumpTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Scrolls [scrollable] down until [done], or gives up after a few screens.
Future<void> scrollDownUntil(WidgetTester tester, Finder scrollable, bool Function() done) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.drag(scrollable, const Offset(0, -1500));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Opens the search for [query] on [tab], as the app does.
Future<List<Route<dynamic>>> pumpSearch(WidgetTester tester, String query, SearchTab tab, {MockXClient? client}) =>
    pumpRoute(
      tester,
      const ResultsScreen(),
      RouteSettings(
        name: routeSearch,
        arguments: SearchArguments(tab, query: query),
      ),
      client: client,
    );
