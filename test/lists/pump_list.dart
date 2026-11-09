import 'package:dart_twitter_api/twitter_api.dart' show AbstractTwitterClient;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/lists/x_list.dart';
import 'package:quax/lists/x_list_screen.dart';

import '../fixtures.dart';
import '../pump_route.dart';

const recordedListId = '1273859202318864390';

// Parsing changes the body it reads, so each use reads the file again
Fixture recordedListPage() => fixture('ListByRestId', recordedListId, unstable: true);

XList get recordedList => XList.fromGraphql(recordedListPage().body)!;

/// The recorded pages of [operation] for the list, in no order.
Iterable<Fixture> listPages(String operation) =>
    fixturesOf(operation).where((page) => page.variables['listId'] == recordedListId);

/// The recorded pages of the Lists tab of a search, in no order.
Iterable<Fixture> listSearchPages() =>
    fixturesOf('SearchTimeline').where((page) => page.variables['product'] == 'Lists');

/// Opens the recorded list as the app does.
Future<List<Route<dynamic>>> openList(WidgetTester tester, {AbstractTwitterClient? client, bool showMembers = false}) =>
    pumpRoute(
      tester,
      const XListScreen(),
      RouteSettings(
        name: routeList,
        arguments: XListScreenArguments(recordedListId, showMembers: showMembers),
      ),
      client: client,
    );
