import 'dart:convert';

import 'package:dart_twitter_api/twitter_api.dart';
import 'package:http/http.dart';

import 'fixtures.dart';

/// Stands in for X: answers a GraphQL GET with the fixture recorded for its
/// operation, the last segment of the path, so a widget that loads its own
/// data renders the recorded response.
class FixtureTwitterClient extends AbstractTwitterClient {
  const FixtureTwitterClient(this.fixtures);

  final Map<String, Fixture> fixtures;

  @override
  Future<Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) async {
    final fixture = fixtures[uri.pathSegments.last];
    if (fixture == null) {
      throw StateError('No fixture to answer ${uri.path}');
    }
    return Response.bytes(utf8.encode(jsonEncode(fixture.body)), 200, headers: {'content-type': 'application/json'});
  }

  @override
  Future<Response> post(Uri uri,
          {Map<String, String>? headers, dynamic body, Encoding? encoding, Duration? timeout}) =>
      throw UnsupportedError('Fixtures only replay GET requests');

  @override
  Future<Response> multipartRequest(Uri uri,
          {List<MultipartFile>? files, Map<String, String>? headers, Duration? timeout}) =>
      throw UnsupportedError('Fixtures only replay GET requests');
}
