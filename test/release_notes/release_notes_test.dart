import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/release_notes/release_notes.dart';
import 'package:quax/release_notes/release_notes_model.dart';

const _releases = [
  ReleaseNote(version: '4.10.0', notes: ['Ten']),
  ReleaseNote(version: '4.9.1', notes: ['Nine one']),
  ReleaseNote(version: '4.9.0', notes: ['Nine']),
  ReleaseNote(version: '4.8.0', notes: ['Eight']),
];

List<String> _versions(List<ReleaseNote> releases) => releases.map((e) => e.version).toList();

void main() {
  group('releaseNotesSince()', () {
    test('Should list every version released after the installed one, up to the current one', () {
      final notes = releaseNotesSince(_releases, installed: '4.8.0', current: '4.9.1');

      expect(_versions(notes), ['4.9.1', '4.9.0'],
          reason: 'The versions skipped by the user should be listed, newest first, but not the installed one');
    });

    test('Should compare the versions by number, not as text', () {
      final notes = releaseNotesSince(_releases, installed: '4.9.1', current: '4.10.0');

      expect(_versions(notes), ['4.10.0'], reason: '4.10.0 comes after 4.9.1 although it sorts before as text');
    });

    test('Should list nothing when the version did not change, or went back', () {
      expect(releaseNotesSince(_releases, installed: '4.9.0', current: '4.9.0'), isEmpty,
          reason: 'A relaunch of the same version has nothing new to show');
      expect(releaseNotesSince(_releases, installed: '4.10.0', current: '4.9.0'), isEmpty,
          reason: 'A downgrade has nothing new to show');
    });

    test('Should only list the current version when no version was stored', () {
      final notes = releaseNotesSince(_releases, installed: null, current: '4.9.1');

      expect(_versions(notes), ['4.9.1'],
          reason: 'Without knowing the previous version, only what this version brings is known to be new');
    });
  });

  test('Should hold the notes of the version in pubspec.yaml first', () {
    final releases = parseReleaseNotes(File(releaseNotesAsset).readAsStringSync());
    final pubspecVersion = RegExp(r'^version: (\d+\.\d+\.\d+)', multiLine: true)
        .firstMatch(File('pubspec.yaml').readAsStringSync())!
        .group(1);

    expect(releases.first.version, pubspecVersion,
        reason: 'The new version job must add the notes of the version it bumps to, at the top');
    expect(releases.every((release) => release.notes.isNotEmpty), isTrue,
        reason: 'Every version in the file should come with its notes');
  });
}
