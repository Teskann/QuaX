import 'dart:convert';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:logging/logging.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

var defaultGroupIcon = '{"pack":"custom","key":"rss_feed"}';

IconData deserializeIconData(String iconData) {
  try {
    var icon = deserializeIcon(jsonDecode(iconData));
    if (icon != null) {
      return icon.data;
    }
  } catch (e) {
    // Simply ignore this exception (failed to deserialize icon)
  }

  // Use this as a default;
  return Icons.rss_feed;
}

Future<SubscriptionGroupGet> readSubscriptionGroup(Database database, String id) async {
  var group = (await database.query(tableSubscriptionGroup, where: 'id = ?', whereArgs: [id])).first;
  if (id == '-1') {
    return _readMainFeed(database, group);
  }

  final subscriptions = [
    for (final kind in SubscriptionKind.values)
      ...(await database.rawQuery(
              'SELECT s.* FROM ${kind.table} s JOIN $tableSubscriptionGroupMember m ON m.profile_id = s.id AND m.kind = ? WHERE m.group_id = ?',
              [kind.name, id]))
          .map(kind.fromRow),
  ];

  // TODO: Factory
  return SubscriptionGroupGet(
      id: group['id'] as String,
      name: group['name'] as String,
      icon: group['icon'] as String,
      subscriptions: subscriptions,
      includeReplies: group['include_replies'] == 1,
      includeRetweets: group['include_retweets'] == 1);
}

Future<SubscriptionGroupGet> _readMainFeed(Database database, Map<String, Object?> group) async {
  var subscriptions =
      (await database.query(tableSubscription)).map((e) => UserSubscription.fromMap(e)).toList(growable: false);
  var groupMemberIds = (await database.query(tableSubscriptionGroupMember,
          columns: ['profile_id'], where: 'kind = ?', whereArgs: [SubscriptionKind.user.name]))
      .map((e) => e['profile_id'] as String)
      .toSet();

  return SubscriptionGroupGet(
      id: '-1',
      name: 'All',
      icon: group['icon'] as String,
      subscriptions: subscriptions,
      includeReplies: group['include_replies'] == 1,
      includeRetweets: group['include_retweets'] == 1,
      includeGroupMembers: group['include_group_members'] == 1,
      groupMemberIds: groupMemberIds);
}

class GroupModel extends Store<SubscriptionGroupGet> {
  final String id;

  GroupModel(this.id)
      : super(SubscriptionGroupGet(
            id: '',
            name: '',
            icon: defaultGroupIcon,
            subscriptions: [],
            includeRetweets: false,
            includeReplies: false));

  Future<void> loadGroup() async {
    await execute(() async => readSubscriptionGroup(await Repository.readOnly(), id));
  }

  Future<void> toggleSubscriptionGroupIncludeReplies(bool value) =>
      _saveFilter('include_replies', value, () => state.includeReplies = value);

  Future<void> toggleSubscriptionGroupIncludeRetweets(bool value) =>
      _saveFilter('include_retweets', value, () => state.includeRetweets = value);

  Future<void> toggleMainFeedIncludeGroupMembers(bool value) =>
      _saveFilter('include_group_members', value, () => state.includeGroupMembers = value);

  Future<void> _saveFilter(String column, bool value, void Function() applyToState) async {
    await execute(() async {
      (await Repository.writable())
          .rawUpdate('UPDATE $tableSubscriptionGroup SET $column = ? WHERE id = ?', [value, state.id]);
      applyToState();
      return state;
    });
  }
}

/// What a group is made of, as the editor changes and saves it.
class GroupDraft {
  /// Null for a group not saved yet.
  final String? id;
  final String name;
  final String icon;
  final Color? color;
  final Set<SubscriptionRef> members;

  const GroupDraft({required this.id, required this.name, required this.icon, required this.color, required this.members});

  static final empty = GroupDraft(id: null, name: '', icon: defaultGroupIcon, color: null, members: const {});

  GroupDraft copyWith({String? name, String? icon, Color? Function()? color, Set<SubscriptionRef>? members}) =>
      GroupDraft(
        id: id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color == null ? this.color : color(),
        members: members ?? this.members,
      );

  bool hasSameContentAs(GroupDraft other) =>
      name == other.name &&
      icon == other.icon &&
      color?.toARGB32() == other.color?.toARGB32() &&
      setEquals(members, other.members);
}

class GroupsModel extends Store<List<SubscriptionGroup>> {
  static final log = Logger('GroupModel');

  final Map<String, VoidCallback> _onGroupsReloaded = {};

  GroupsModel() : super([]);

  void addReloadListener(String key, VoidCallback callback) {
    _onGroupsReloaded[key] = callback;
  }

  void removeReloadListener(String key) {
    _onGroupsReloaded.remove(key);
  }

  Future<void> deleteGroup(String id) async {
    log.info('Deleting the group $id');

    await execute(() async {
      var database = await Repository.writable();

      await database.delete(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [id]);
      await database.delete(tableSubscriptionGroup, where: 'id = ?', whereArgs: [id]);

      return state.where((e) => e.id != id).toList();
    });
  }

  /// Without [notifyFeeds], the feeds are left for a reload of the subscriptions to refresh.
  Future reloadGroups({bool notifyFeeds = true}) async {
    log.info('Listing subscriptions groups');

    await execute(() async {
      var database = await Repository.readOnly();

      var query =
          "SELECT g.id, g.name, g.icon, g.color, g.created_at, COUNT(gm.profile_id) AS number_of_members FROM $tableSubscriptionGroup g LEFT JOIN $tableSubscriptionGroupMember gm ON gm.group_id = g.id WHERE g.id != '-1' GROUP BY g.id ORDER BY g.name COLLATE NOCASE ASC";

      return (await database.rawQuery(query)).map((e) => SubscriptionGroup.fromMap(e)).toList(growable: false);
    });
    if (notifyFeeds) {
      for (final callback in _onGroupsReloaded.values) {
        callback();
      }
    }
  }

  Future<List<SubscriptionGroupMember>> listGroupMembers() async {
    var database = await Repository.readOnly();
    return (await database.query(tableSubscriptionGroupMember)).map(SubscriptionGroupMember.fromMap).toList();
  }

  Future<GroupDraft> loadGroupDraft(String? id) async {
    var database = await Repository.readOnly();
    var group = id == null ? const [] : await database.query(tableSubscriptionGroup, where: 'id = ?', whereArgs: [id]);
    if (group.isEmpty) {
      return GroupDraft.empty;
    }
    var members = await database.query(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [id]);
    return GroupDraft(
      id: group.first['id'] as String,
      name: group.first['name'] as String,
      icon: group.first['icon'] as String,
      color: group.first['color'] == null ? null : Color(group.first['color'] as int),
      members: refsOf(members.map(SubscriptionGroupMember.fromMap)).toSet(),
    );
  }

  /// Saves [draft] under [name]: a new group when its id is null.
  Future<void> saveGroup(GroupDraft draft, String name) async {
    final database = await Repository.writable();
    final id = draft.id ?? const Uuid().v4();
    final details = {'name': name, 'color': draft.color?.toARGB32(), 'icon': draft.icon};
    final batch = database.batch();
    if (draft.id == null) {
      batch.insert(tableSubscriptionGroup, {'id': id, ...details});
    } else {
      batch.update(tableSubscriptionGroup, details, where: 'id = ?', whereArgs: [id]);
    }
    batch.delete(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [id]);
    for (final member in draft.members) {
      batch.insert(tableSubscriptionGroupMember, memberRow(id, member));
    }
    await batch.commit(noResult: true);
    await reloadGroups();
  }
}

Map<String, Object> memberRow(String groupId, SubscriptionRef member) =>
    {'group_id': groupId, 'profile_id': member.id, 'kind': member.kind.name};

/// Members of a kind this version does not know are left out.
Iterable<SubscriptionRef> refsOf(Iterable<SubscriptionGroupMember> members) => members
    .map((m) => (kind: SubscriptionKind.named(m.kind), id: m.profile))
    .where((m) => m.kind != null)
    .map((m) => SubscriptionRef(m.kind!, m.id));

/// The members of each group, by group id.
class GroupMembershipsModel extends Store<Map<String, Set<SubscriptionRef>>> {
  final GroupsModel groups;

  GroupMembershipsModel(this.groups) : super(const {}) {
    groups.observer(onState: (_) => reload());
  }

  Future<void> reload() async {
    await execute(() async => membersByGroup(await groups.listGroupMembers()));
  }

  /// Puts [members] in the group, or takes them out of it. The groups are left for the caller to reload,
  /// once after many changes.
  Future<void> setMembership(String groupId, Iterable<SubscriptionRef> members, {required bool member}) async {
    final batch = (await Repository.writable()).batch();
    for (final ref in members) {
      if (member) {
        batch.insert(tableSubscriptionGroupMember, memberRow(groupId, ref), conflictAlgorithm: ConflictAlgorithm.ignore);
      } else {
        batch.delete(tableSubscriptionGroupMember,
            where: 'group_id = ? AND kind = ? AND profile_id = ?', whereArgs: [groupId, ref.kind.name, ref.id]);
      }
    }
    await batch.commit(noResult: true);
    await reload();
  }
}

Map<String, Set<SubscriptionRef>> membersByGroup(Iterable<SubscriptionGroupMember> memberships) => memberships.fold(
    {}, (members, m) => members..putIfAbsent(m.group, () => {}).addAll(refsOf([m])));

Map<SubscriptionRef, List<SubscriptionGroup>> groupsBySubscription(
        List<SubscriptionGroup> groups, Map<String, Set<SubscriptionRef>> membersByGroup) =>
    {
      for (final ref in membersByGroup.values.expand((members) => members).toSet())
        ref: groups.where((group) => membersByGroup[group.id]?.contains(ref) ?? false).toList(),
    };
