import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/record/request_check.dart';

Uri _url(Map<String, dynamic> parameters) => Uri.https('x.com', '/i/api/graphql/abc/HomeTimeline',
    {for (final entry in parameters.entries) entry.key: jsonEncode(entry.value)});

Map<String, dynamic> _fixture({Object? variables = const {}, int status = 200, Object body = const {'data': {}}}) =>
    {'variables': variables, 'status': status, 'body': body};

void main() {
  group('Request parameters', () {
    test('Should read the parameters of a GET from its URL', () {
      final parameters = requestParameters(_url({'variables': {'count': 20}, 'features': {'a': true}}), null);

      expect(parameters['variables'], {'count': 20}, reason: 'A GET carries its variables in the URL');
      expect(parameters['features'], {'a': true}, reason: 'A GET carries its features in the URL');
      expect(parameters['fieldToggles'], isNull, reason: 'A parameter absent from the request should stay null');
    });

    test('Should read the parameters of a POST from its body', () {
      final parameters = requestParameters(
          _url({}), jsonEncode({'variables': {'count': 20}, 'features': {'a': true}, 'queryId': 'abc'}));

      expect(parameters['variables'], {'count': 20}, reason: 'HomeTimeline is a POST and carries its variables in the body');
      expect(parameters['features'], {'a': true}, reason: 'A POST carries its features in the body');
    });

    test('Should fall back on the URL for what a POST body leaves out', () {
      final parameters = requestParameters(_url({'features': {'a': true}}), jsonEncode({'variables': {}}));

      expect(parameters['features'], {'a': true}, reason: 'A parameter missing from the body may still be in the URL');
    });
  });

  group('Fixture problems', () {
    test('Should accept a sound fixture, even with empty variables', () {
      expect(fixtureProblem(_fixture()), isNull, reason: 'Empty variables are what X sends for some operations');
    });

    test('Should reject a fixture whose variables were not found', () {
      expect(fixtureProblem(_fixture(variables: null)), contains('no variables'),
          reason: 'X always sends variables, so missing ones mean the request was misread');
    });

    test('Should reject an error answer', () {
      expect(fixtureProblem(_fixture(status: 429)), contains('429'), reason: 'A rate limit is not what the page shows');
    });

    test('Should reject a body that is not JSON', () {
      expect(fixtureProblem(_fixture(body: '<html>')), contains('not JSON'),
          reason: 'Every GraphQL answer of X is JSON');
    });
  });

  group('Rate limit end', () {
    Map<String, dynamic> limited(int status, String? reset) =>
        {..._fixture(status: status), 'headers': {'x-rate-limit-reset': ?reset}};

    test('Should wait for the latest reset among the rate limited answers', () {
      final end = rateLimitEnd([limited(429, '1000'), limited(429, '2000')]);

      expect(end, DateTime.fromMillisecondsSinceEpoch(2000 * 1000),
          reason: 'Every limited operation must be lifted before visiting again');
    });

    test('Should ignore the reset of an answer that was not rate limited', () {
      expect(rateLimitEnd([limited(200, '1000'), limited(500, '2000')]), isNull,
          reason: 'X sends a reset time with every answer, rate limited or not');
    });

    test('Should not know when a rate limit without a reset time ends', () {
      expect(rateLimitEnd([limited(429, null)]), isNull, reason: 'Without the header there is no time to wait for');
    });
  });
}
