import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';

class ReleaseNote {
  final String version;
  final List<String> notes;

  const ReleaseNote({required this.version, required this.notes});

  factory ReleaseNote.fromJson(Map<String, dynamic> json) => ReleaseNote(
        version: json['version'] as String? ?? '',
        notes: (json['notes'] as List<dynamic>? ?? []).whereType<String>().toList(),
      );
}

List<ReleaseNote> parseReleaseNotes(String content) =>
    (jsonDecode(content) as List<dynamic>).whereType<Map<String, dynamic>>().map(ReleaseNote.fromJson).toList();

/// The notes of the versions after [installed], up to [current]. Only those of [current] if [installed] is unknown.
List<ReleaseNote> releaseNotesSince(List<ReleaseNote> releases, {required String? installed, required String current}) {
  final now = Version.parse(current);
  if (installed == null) {
    return releases.where((release) => Version.parse(release.version) == now).toList();
  }
  final last = Version.parse(installed);
  return releases.where((release) {
    final version = Version.parse(release.version);
    return version > last && version <= now;
  }).toList();
}
