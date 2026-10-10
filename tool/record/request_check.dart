import 'dart:convert';

import 'package:collection/collection.dart';

const _parameters = ['features', 'fieldToggles', 'variables'];

/// The GraphQL parameters of a request. X sends them in the URL (GET) or in a
/// JSON body (POST, as HomeTimeline does); a POST may still leave some in the URL.
Map<String, dynamic> requestParameters(Uri uri, String? postData) {
  final posted = decodeJson(postData);
  return {
    for (final name in _parameters) name: (posted is Map ? posted[name] : null) ?? decodeJson(uri.queryParameters[name]),
  };
}

/// Why [fixture] must not be written, or null when it is sound. X always sends
/// variables, `{}` at the least, so missing ones mean the request was misread.
String? fixtureProblem(Map<String, dynamic> fixture) => switch (fixture) {
      {'variables': null} => 'no variables found in the request',
      {'status': final int status} when status != 200 => 'X answered $status',
      {'body': String()} => 'the body is not JSON',
      _ => null,
    };

/// When X lifts the rate limit that rejected some of [fixtures], from the reset
/// time it sends with every answer; null when none of them hit one, or X did not say.
DateTime? rateLimitEnd(Iterable<Map<String, dynamic>> fixtures) => fixtures
    .where((fixture) => fixture['status'] == 429)
    .map((fixture) => int.tryParse('${(fixture['headers'] as Map?)?['x-rate-limit-reset']}'))
    .nonNulls
    .map((seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000))
    .maxOrNull;

dynamic decodeJson(String? raw) {
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}
