import 'dart:convert';
import 'dart:io';

/// One recorded X response, with the scenario that produced it.
class Fixture {
  Fixture(this.path, Map<String, dynamic> json)
      : scenario = json['scenario'] as String? ?? path,
        sourceUrl = json['sourceUrl'] as String? ?? '',
        queryId = json['queryId'] as String? ?? '',
        body = json['body'] as Map<String, dynamic>? ?? const {};

  final String path;
  final String scenario;
  final String sourceUrl;
  final String queryId;
  final Map<String, dynamic> body;

  @override
  String toString() => scenario;
}

Fixture _read(File file) => Fixture(file.path, jsonDecode(file.readAsStringSync()) as Map<String, dynamic>);

List<Fixture> fixturesOf(String operation) {
  final directory = Directory('test/fixtures/$operation');
  if (!directory.existsSync()) {
    return const [];
  }
  final files = directory.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files.map(_read).toList();
}

/// The fixture recorded as `test/fixtures/<operation>/<name>.json`.
Fixture fixture(String operation, String name) => _read(File('test/fixtures/$operation/$name.json'));
