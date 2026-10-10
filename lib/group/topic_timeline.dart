import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:sqflite/sqflite.dart';

/// Makes a timeline of the search [query]: saves it as a search subscription and puts it in the group called [name],
/// which is created when there is none. Returns the id of that group.
Future<String> createTopicTimeline(GroupsModel groups, String name, String query) async {
  final database = await Repository.writable();
  await database.insert(tableSearchSubscription, {'id': query}, conflictAlgorithm: ConflictAlgorithm.ignore);

  final existing = await _groupIdNamed(database, name);
  if (existing == null) {
    await groups.saveGroup(null, name, defaultGroupIcon, null, {query});
  } else {
    await database.insert(tableSubscriptionGroupMember, {'group_id': existing, 'profile_id': query},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  // saveGroup leaves the stale list in the state when it ends, so the tabs are reloaded once more
  await groups.reloadGroups();
  return (await _groupIdNamed(database, name))!;
}

Future<String?> _groupIdNamed(Database database, String name) async {
  final rows = await database.query(tableSubscriptionGroup,
      columns: ['id'], where: "name = ? COLLATE NOCASE AND id != '-1'", whereArgs: [name], limit: 1);
  return rows.isEmpty ? null : rows.first['id'] as String;
}
