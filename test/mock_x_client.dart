import 'dart:convert';

import 'package:dart_twitter_api/twitter_api.dart';
import 'package:http/http.dart';

import '../tool/mock_x/fixture_map.dart';

/// Sends the app's requests through the mock of X, which answers only a request
/// identical to a recorded one, and keeps what it answered.
class MockXClient extends AbstractTwitterClient {
  MockXClient(this.fixtures);

  final FixtureMap fixtures;
  final answers = <MockAnswer>[];

  @override
  Future<Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) async {
    final answer = fixtures.answer(uri);
    answers.add(answer);
    return Response.bytes(utf8.encode(answer.body), answer.status,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  @override
  Future<Response> post(Uri uri, {Map<String, String>? headers, dynamic body, Encoding? encoding, Duration? timeout}) =>
      throw UnsupportedError('The mock only answers GET requests');

  @override
  Future<Response> multipartRequest(Uri uri,
          {List<MultipartFile>? files, Map<String, String>? headers, Duration? timeout}) =>
      throw UnsupportedError('The mock only answers GET requests');
}
