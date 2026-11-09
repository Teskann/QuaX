import 'dart:convert';

import 'package:dart_twitter_api/twitter_api.dart' show AbstractTwitterClient;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/community/community.dart';
import 'package:quax/community/community_screen.dart';
import 'package:quax/constants.dart';

import '../fixtures.dart';
import '../pump_route.dart';

final recordedCommunity = fixture('CommunityQuery', 'vars-9a8157', unstable: true);
final community = Community.fromGraphql(recordedCommunity.body)!;

// Parsing changes the body it reads, so each use reads the file again
Fixture recordedPosts() => fixture('CommunityTweetsTimeline', 'vars-a9e356', unstable: true);

/// Opens the recorded community as the app does.
Future<List<Route<dynamic>>> openCommunity(WidgetTester tester,
        {bool showAbout = false, AbstractTwitterClient? client, Map<String, dynamic> prefs = const {}}) =>
    pumpRoute(
      tester,
      const CommunityScreen(),
      RouteSettings(name: routeCommunity, arguments: CommunityScreenArguments(community.id, showAbout: showAbout)),
      client: client,
      prefs: prefs,
    );

/// The value of [variable] in each [operation] request the app sent, in order.
List<dynamic> sentVariable(List<Uri> uris, String operation, String variable) => uris
    .where((uri) => uri.pathSegments.last == operation)
    .map((uri) => (jsonDecode(uri.queryParameters['variables']!) as Map)[variable])
    .toList();
