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
}
