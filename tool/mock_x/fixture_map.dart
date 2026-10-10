import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';

final _graphql = RegExp(r'^/i/api/graphql/([\w-]+)/(\w+)$');
const _equality = DeepCollectionEquality();
const _parameters = ['variables', 'features', 'fieldToggles'];

/// One fixture of test/fixtures, read back as the request that produced it.
class RecordedRequest {
  RecordedRequest(this.file, Map<String, dynamic> json)
      : host = json['host'] as String? ?? '',
        queryId = json['queryId'] as String? ?? '',
        operation = json['operation'] as String? ?? '',
        parameters = {for (final name in _parameters) name: json[name]},
        status = json['status'] as int? ?? 200,
        body = json['body'];

  final String file;
  final String host;
  final String queryId;
  final String operation;
  final Map<String, dynamic> parameters;
  final int status;
  final dynamic body;

  String get encodedBody => body is String ? body as String : jsonEncode(body);
}

class MockAnswer {
  const MockAnswer(this.status, this.body, {this.fixture});

  final int status;
  final String body;

  final String? fixture;

  bool get matched => fixture != null;
}

class FixtureMap {
  FixtureMap(this.requests);

  factory FixtureMap.load(Directory directory) {
    final files = directory.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final requests = files
        .map((file) => (file, jsonDecode(file.readAsStringSync())))
        .where((entry) => entry.$2 is Map<String, dynamic> && entry.$2['operation'] != null)
        .map((entry) => RecordedRequest(entry.$1.path, entry.$2 as Map<String, dynamic>))
        .toList();
    return FixtureMap(requests);
  }

  final List<RecordedRequest> requests;

  MockAnswer answer(Uri uri) {
    final match = _graphql.firstMatch(uri.path);
    if (match == null) {
      return MockAnswer(501, 'No fixture for $uri: only X GraphQL requests (/i/api/graphql/<queryId>/<Operation>) '
          'are recorded by tool/record/capture.dart.');
    }
    final sent = _Sent(uri, match.group(1)!, match.group(2)!);
    final candidates = requests.where((r) => r.operation == sent.operation).toList();
    final exact = candidates.firstWhereOrNull((r) => sent.differencesWith(r).isEmpty);
    if (exact != null) {
      return MockAnswer(exact.status, exact.encodedBody, fixture: exact.file);
    }
    return MockAnswer(501, _explain(sent, candidates));
  }

  String _explain(_Sent sent, List<RecordedRequest> candidates) {
    if (candidates.isEmpty) {
      final known = requests.map((r) => r.operation).toSet().sorted((a, b) => a.compareTo(b));
      return 'No fixture recorded for ${sent.operation}.\nRecorded operations: ${known.join(', ')}';
    }
    final closest = candidates.sorted((a, b) => sent.differencesWith(a).length - sent.differencesWith(b).length).first;
    return [
      'No fixture matches this ${sent.operation} request exactly.',
      'Closest: ${closest.file}',
      ...sent.differencesWith(closest).map((difference) => '  - $difference'),
    ].join('\n');
  }
}

class _Sent {
  _Sent(Uri uri, this.queryId, this.operation)
      : host = uri.host,
        parameters = {for (final name in _parameters) name: _decode(uri.queryParameters[name])},
        unknownParameters = uri.queryParameters.keys.where((name) => !_parameters.contains(name)).toList();

  final String host;
  final String queryId;
  final String operation;
  final Map<String, dynamic> parameters;
  final List<String> unknownParameters;

  /// Every way this request differs from [recorded]; empty when it is the same.
  List<String> differencesWith(RecordedRequest recorded) => [
        if (host != recorded.host) 'host: sent $host, recorded ${recorded.host}',
        if (queryId != recorded.queryId) 'queryId: sent $queryId, recorded ${recorded.queryId}',
        ...unknownParameters.map((name) => 'parameter $name: sent, never recorded'),
        for (final name in _parameters) ..._compare(name, parameters[name], recorded.parameters[name]),
      ];
}

dynamic _decode(String? raw) => raw == null ? null : jsonDecode(raw);

List<String> _compare(String name, dynamic sent, dynamic recorded) {
  if (_equality.equals(sent, recorded)) return const [];
  if (sent is! Map || recorded is! Map) {
    return ['$name: sent ${jsonEncode(sent)}, recorded ${jsonEncode(recorded)}'];
  }
  return [
    ...recorded.keys.where((key) => !sent.containsKey(key)).map((key) => '$name.$key: missing, recorded ${jsonEncode(recorded[key])}'),
    ...sent.keys.where((key) => !recorded.containsKey(key)).map((key) => '$name.$key: sent ${jsonEncode(sent[key])}, never recorded'),
    ...sent.keys
        .where((key) => recorded.containsKey(key) && !_equality.equals(sent[key], recorded[key]))
        .map((key) => '$name.$key: sent ${jsonEncode(sent[key])}, recorded ${jsonEncode(recorded[key])}'),
  ];
}
