// ignore_for_file: avoid_print
//
// Serves the recorded fixtures as if it were X, for an app started with
//   --dart-define=QUAX_MOCK_X=http://localhost:8787
// which sends https://x.com/i/api/... to http://localhost:8787/x.com/i/api/...
//
//   fvm dart run tool/mock_x/server.dart [--port 8787]

import 'dart:io';

import 'fixture_map.dart';

Future<void> main(List<String> args) async {
  final portIndex = args.indexOf('--port');
  final port = portIndex >= 0 ? int.parse(args[portIndex + 1]) : 8787;
  final fixtures = FixtureMap.load(Directory('test/fixtures'));
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('${fixtures.requests.length} recorded requests, listening on http://localhost:$port');

  await for (final request in server) {
    final answer = fixtures.answer(_original(request.uri));
    print('${answer.status} ${request.uri.path}');
    if (!answer.matched) print(answer.body);
    request.response
      ..statusCode = answer.status
      ..headers.contentType = answer.matched ? ContentType.json : ContentType.text
      ..write(answer.body);
    await request.response.close();
  }
}

/// /x.com/i/api/graphql/... back to https://x.com/i/api/graphql/...
Uri _original(Uri uri) => uri.pathSegments.isEmpty
    ? uri
    : Uri.https(uri.pathSegments.first, uri.pathSegments.skip(1).join('/'))
        .replace(query: uri.hasQuery ? uri.query : null);
