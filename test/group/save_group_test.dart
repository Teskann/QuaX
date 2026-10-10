import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;
  late GroupsModel groups;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('quax_save_group');
    await databaseFactoryFfi.setDatabasesPath(directory.path);
    await Repository().migrate();
    groups = GroupsModel(PrefServiceCache(defaults: {
      optionSubscriptionGroupsOrderByAscending: true,
      optionSubscriptionGroupsOrderByField: 'name',
    }));
    await groups.reloadGroups();
  });

  tearDown(() async {
    final database = await Repository.writable();
    await database.close();
    await directory.delete(recursive: true).catchError((_) => directory);
  });

  test('Should list a new group once it is saved', () async {
    await groups.saveGroup(null, 'Friends', 'rss_feed', null, {'1'});

    expect(groups.state.map((e) => e.name), ['Friends'],
        reason: 'The groups screen reads this list, so a saved group must not vanish from it');
  });

  test('Should keep the other groups listed when one is edited', () async {
    await groups.saveGroup(null, 'Friends', 'rss_feed', null, {'1'});
    await groups.saveGroup(null, 'Work', 'rss_feed', null, {'2'});
    final friends = groups.state.firstWhere((e) => e.name == 'Friends');

    await groups.saveGroup(friends.id, 'Family', 'rss_feed', null, {'1', '3'});

    expect(groups.state.map((e) => e.name), ['Family', 'Work'],
        reason: 'Editing a group should rename it in the list and leave the others there');
  });
}
