import 'package:material_ui/material_ui.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

class ImportDataModel extends ChangeNotifier {
  static final log = Logger('HomeModel');

  Future importData(Map<String, List<ToMappable>> data) async {
    var database = await Repository.writable();

    var batch = database.batch();

    for (var pair in data.entries) {
      for (var datum in pair.value) {
        if (datum is SavedTweet) {
          _importSavedTweet(batch, datum);
        } else {
          batch.insert(pair.key, datum.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }

      log.info('Imported data into ${pair.key}');
    }

    await batch.commit();
  }

  // A post already saved, or saved in several backups, keeps the earliest date it was saved
  void _importSavedTweet(Batch batch, SavedTweet tweet) {
    final row = tweet.toMap();
    batch.rawInsert(
        'INSERT OR REPLACE INTO $tableSavedTweet (id, content, user_id, folder_id, saved_at) VALUES (?, ?, ?, ?, '
        'MIN(COALESCE(?, CURRENT_TIMESTAMP), COALESCE((SELECT saved_at FROM $tableSavedTweet WHERE id = ?), CURRENT_TIMESTAMP)))',
        [row['id'], row['content'], row['user_id'], row['folder_id'], row['saved_at'], row['id']]);
  }
}
