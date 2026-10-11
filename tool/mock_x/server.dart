// ignore_for_file: avoid_print
//
// Serves the recorded fixtures as if it were X, for an app started with
//   --dart-define=QUAX_MOCK_X=http://localhost:8787
// which sends https://x.com/i/api/... to http://localhost:8787/x.com/i/api/...
//
//   fvm dart run tool/mock_x/server.dart [--port 8787]

import 'dart:io';

import 'fixture_map.dart';
import 'mock_server.dart';

Future<void> main(List<String> args) async {
  final portIndex = args.indexOf('--port');
  final port = portIndex >= 0 ? int.parse(args[portIndex + 1]) : 8787;
  final fixtures = FixtureMap.load(Directory('test/fixtures'));
  await serveFixtures(fixtures, port: port, onAnswer: (uri, answer) {
    print('${answer.status} ${uri.path}');
    if (!answer.matched) print(answer.body);
  });
  print('${fixtures.requests.length} recorded requests, listening on http://localhost:$port');
}
