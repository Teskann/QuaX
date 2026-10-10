import 'dart:convert';
import 'dart:io';

/// One recorded X response, with the scenario that produced it.
class Fixture {
  Fixture(this.path, Map<String, dynamic> json)
      : scenario = json['scenario'] as String? ?? path,
        sourceUrl = json['sourceUrl'] as String? ?? '',
        queryId = json['queryId'] as String? ?? '',
        unstable = json['unstable'] as bool? ?? false,
        status = json['status'] as int? ?? 200,
        // An error X answered (a 503 and its empty body) is recorded as it came
        body = json['body'] is Map<String, dynamic> ? json['body'] : const {};

  final String path;
  final String scenario;
  final String sourceUrl;
  final String queryId;

  /// Its content changes from one capture to the next, see tool/record/README.md.
  final bool unstable;
  final int status;
  final Map<String, dynamic> body;

  @override
  String toString() => scenario;
}

Fixture _read(File file) => Fixture(file.path, jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);

/// Every answer recorded for [operation]. An error X answered while recording
/// is left out: the app never parses one, it fails on the status first.
List<Fixture> fixturesOf(String operation) {
  final directory = Directory('test/fixtures/$operation');
  if (!directory.existsSync()) {
    return const [];
  }
  final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files.map(_read).where((fixture) => fixture.status == 200).toList();
}

/// The fixture recorded as `test/fixtures/<operation>/<name>.json`.
///
/// An [unstable] fixture changes with every capture, so a test that reads one
/// says so with [unstable], and checks its shape only, never a name, a text or
/// a count written in the test.
Fixture fixture(String operation, String name, {bool unstable = false}) {
  final read = _read(File('test/fixtures/$operation/$name.json'));
  if (read.unstable && !unstable) {
    throw StateError('${read.path} changes with every capture: pass unstable: true and check its shape only');
  }
  return read;
}
