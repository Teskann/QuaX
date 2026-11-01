import 'package:flutter/services.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:logging/logging.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/release_notes/release_notes.dart';

const releaseNotesAsset = 'assets/release_notes.json';

/// The release notes the user has not hidden yet.
class ReleaseNotesModel extends Store<List<ReleaseNote>> {
  static final log = Logger('ReleaseNotesModel');

  final String currentVersion;

  ReleaseNotesModel(this.currentVersion) : super([]);

  Future<void> load() async {
    try {
      final releases = parseReleaseNotes(await rootBundle.loadString(releaseNotesAsset));
      update(releaseNotesSince(releases, installed: await _readInstalledVersion(), current: currentVersion),
          force: true);
    } catch (e, stackTrace) {
      log.warning('Unable to load the release notes', e, stackTrace);
    }
  }

  /// Hides the notes. They won't show again for this version.
  Future<void> hide() async {
    if (state.isEmpty) {
      return;
    }
    update([], force: true);
    try {
      await _saveInstalledVersion();
    } catch (e, stackTrace) {
      log.warning('Unable to save the installed version', e, stackTrace);
    }
  }

  Future<String?> _readInstalledVersion() async {
    final database = await Repository.readOnly();
    final rows = await database.query(tableInstalledVersion, columns: ['version'], limit: 1);
    return rows.isEmpty ? null : rows.first['version'] as String?;
  }

  Future<void> _saveInstalledVersion() async {
    final database = await Repository.writable();
    await database.transaction((txn) async {
      await txn.delete(tableInstalledVersion);
      await txn.insert(tableInstalledVersion, {'version': currentVersion});
    });
  }
}
