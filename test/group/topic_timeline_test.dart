import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/topic_timeline.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _technology = '(technology OR tech OR gadgets OR software) min_faves:20 -filter:replies';
const _football = '(football OR soccer OR "Champions League") min_faves:20 -filter:replies';

void main() {
  late Directory directory;
  late GroupsModel groups;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('quax_topic_timeline');
    await databaseFactoryFfi.setDatabasesPath(directory.path);
    await Repository().migrate();
    groups = GroupsModel(PrefServiceCache(defaults: {
      optionSubscriptionGroupsOrderByAscending: true,
      optionSubscriptionGroupsOrderByField: 'name',
    }));
  });

  tearDown(() async {
    final database = await Repository.writable();
    await database.close();
    await directory.delete(recursive: true).catchError((_) => directory);
  });

  Future<List<Map<String, Object?>>> rows(String table) async => (await Repository.writable()).query(table);

  group('createTopicTimeline', () {
    test('Should save the search, create a group named after the topic and put the search in it', () async {
      final id = await createTopicTimeline(groups, 'Technology', _technology);

      final searches = await rows(tableSearchSubscription);
      expect(searches.map((e) => e['id']), [_technology], reason: 'The query should be saved as a search');
      final group = await rows(tableSubscriptionGroup);
      expect(group.where((e) => e['id'] == id).map((e) => e['name']), ['Technology'],
          reason: 'The returned id should be the one of the new group');
      final members = await rows(tableSubscriptionGroupMember);
      expect(members.map((e) => (e['group_id'], e['profile_id'])), [(id, _technology)],
          reason: 'The search should be the only member of the group');
    });

    test('Should store the query exactly, with its operators and quotes', () async {
      await createTopicTimeline(groups, 'Football (soccer)', _football);

      final searches = await rows(tableSearchSubscription);
      expect(searches.single['id'], _football, reason: 'The operators must reach the search untouched');
    });

    test('Should reload the groups so that the home header gets a new tab', () async {
      final id = await createTopicTimeline(groups, 'Technology', _technology);

      expect(groups.state.map((e) => e.id), [id], reason: 'The groups model should list the new group');
      expect(groups.state.single.numberOfMembers, 1, reason: 'The new group should hold the search');
    });

    test('Should reuse the group of the same name instead of duplicating it', () async {
      final first = await createTopicTimeline(groups, 'Technology', _technology);
      final second = await createTopicTimeline(groups, 'Technology', _technology);

      expect(second, first, reason: 'The same topic should lead to the same group');
      final named = (await rows(tableSubscriptionGroup)).where((e) => e['name'] == 'Technology');
      expect(named, hasLength(1), reason: 'No duplicate group should be created');
      expect(await rows(tableSearchSubscription), hasLength(1), reason: 'No duplicate search should be saved');
      expect(await rows(tableSubscriptionGroupMember), hasLength(1), reason: 'No duplicate membership');
    });

    test('Should reuse the group whatever the case of its name and add the new search to it', () async {
      final first = await createTopicTimeline(groups, 'Technology', _technology);
      final second = await createTopicTimeline(groups, 'technology', 'gadgets');

      expect(second, first, reason: 'Names differing by case are the same topic');
      final members = await rows(tableSubscriptionGroupMember);
      expect(members.map((e) => e['profile_id']), unorderedEquals([_technology, 'gadgets']),
          reason: 'A different search of the same topic joins the existing group');
      expect(groups.state.single.numberOfMembers, 2, reason: 'The reloaded groups should count both searches');
    });

    test('Should make a separate group for each topic', () async {
      final technology = await createTopicTimeline(groups, 'Technology', _technology);
      final football = await createTopicTimeline(groups, 'Football (soccer)', _football);

      expect(football, isNot(technology), reason: 'Different topics deserve different tabs');
      expect(groups.state, hasLength(2), reason: 'Both groups should be listed');
    });
  });
}
