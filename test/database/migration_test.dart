import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  final plan = Repository.migrationPlan();

  Future<Database> databaseAt(int version) async {
    final database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    addTearDown(database.close);
    await plan(database, 0, version);
    return database;
  }

  Future<void> migrate(Database database, int from, int to) => plan(database, from, to);

  test('Should create a fresh database at the latest version', () async {
    final database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            singleInstance: false, version: databaseVersion, onCreate: plan.call));
    addTearDown(database.close);

    expect(await database.getVersion(), databaseVersion, reason: 'A new install should start at the latest schema');
  });

  group('Version 28', () {
    test('Should include the accounts in groups in the feeds that existed before', () async {
      final database = await databaseAt(27);
      await database.insert(tableSubscriptionGroup, {'id': 'group', 'name': 'Group', 'icon': ''});

      await migrate(database, 27, 28);

      final groups = await database.query(tableSubscriptionGroup, columns: ['id', 'include_group_members']);
      expect(groups.map((e) => e['include_group_members']), everyElement(1),
          reason: 'The main feed must keep showing the accounts in groups until the user turns the filter off');
      expect(groups.map((e) => e['id']), containsAll(['-1', 'group']),
          reason: 'The main feed row, where the filter is read, must be migrated along with the groups');
    });

    test('Should include the accounts in groups in a feed created afterwards', () async {
      final database = await databaseAt(28);

      await database.insert(tableSubscriptionGroup, {'id': 'group', 'name': 'Group', 'icon': ''});

      final group = await database.query(tableSubscriptionGroup, where: 'id = ?', whereArgs: ['group']);
      expect(group.single['include_group_members'], 1,
          reason: 'A feed created without the column set must get the default, as the code reads it with == 1');
    });
  });

  group('Version 29', () {
    test('Should store a single installed version', () async {
      final database = await databaseAt(28);

      await migrate(database, 28, 29);
      await database.insert(tableInstalledVersion, {'version': '4.20.1'});

      final rows = await database.query(tableInstalledVersion);
      expect(rows.single['version'], '4.20.1', reason: 'The release notes are computed from this version');
    });
  });

  group('Version 30', () {
    test('Should keep the cached pages of the feeds in their order', () async {
      final database = await databaseAt(29);
      for (final (cursorId, cursor) in [(2, 'second'), (1, 'first')]) {
        await database.insert(tableFeedGroupChunk,
            {'cursor_id': cursorId, 'hash': 'chunk', 'cursor_bottom': cursor, 'response': '[]'});
      }

      await migrate(database, 29, 30);

      final pages =
          await database.query(tableFeedGroupChunk, where: 'hash = ?', whereArgs: ['chunk'], orderBy: 'rowid');
      expect(pages.map((e) => e['cursor_bottom']), ['first', 'second'],
          reason: 'The last page of a chunk gives the cursor its next page starts from');
    });

    test('Should drop the numbers the pages of a feed used to share', () async {
      final database = await databaseAt(30);

      final tables = await database.query('sqlite_master', where: 'name = ?', whereArgs: [tableFeedGroupCursor]);
      expect(tables, isEmpty, reason: 'Each chunk follows its own cursor, so the shared page numbers are useless');
    });

    test('Should open the feeds that existed before at their top', () async {
      final database = await databaseAt(29);

      await migrate(database, 29, 30);

      final feeds = await database.query(tableSubscriptionGroup, columns: ['feed_position']);
      expect(feeds.map((e) => e['feed_position']), everyElement(isNull),
          reason: 'No tweet was remembered yet, so the feeds should open on their newest tweet');
    });
  });
}
