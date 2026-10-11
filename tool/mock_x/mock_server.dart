import 'dart:io';

import 'fixture_map.dart';

/// Answers the requests sent to [port] with [fixtures], as if it were X, and reports each answer to [onAnswer].
Future<HttpServer> serveFixtures(FixtureMap fixtures,
    {int port = 8787, required void Function(Uri uri, MockAnswer answer) onAnswer}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  server.listen((request) async {
    final answer = fixtures.answer(_original(request.uri));
    onAnswer(request.uri, answer);
    request.response
      ..statusCode = answer.status
      ..headers.contentType = answer.matched ? ContentType.json : ContentType.text
      ..write(answer.body);
    await request.response.close();
  });
  return server;
}

/// /x.com/i/api/graphql/... back to https://x.com/i/api/graphql/...
Uri _original(Uri uri) => uri.pathSegments.isEmpty
    ? uri
    : Uri.https(uri.pathSegments.first, uri.pathSegments.skip(1).join('/'))
        .replace(query: uri.hasQuery ? uri.query : null);
