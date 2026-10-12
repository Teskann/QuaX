import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart' show GroupsModel, defaultGroupIcon;
import 'package:quax/home/home_model.dart';
import 'package:quax/settings/_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  SettingsData full() => SettingsData(
        settings: {'theme.mode': 'dark'},
        searchSubscriptions: [SearchSubscription(id: '#flutter', createdAt: DateTime(2026, 9, 4, 9))],
        userSubscriptions: [
          UserSubscription(
              id: '1',
              screenName: 'dogs',
              name: 'Dogs',
              profileImageUrlHttps: null,
              verified: true,
              createdAt: DateTime(2026, 9, 4, 9),
              inFeed: true)
        ],
        subscriptionGroups: [
          SubscriptionGroup(
              id: 'g1',
              name: 'Pets',
              icon: defaultGroupIcon,
              color: null,
              numberOfMembers: 1,
              createdAt: DateTime(2026, 9, 4, 9))
        ],
        subscriptionGroupMembers: [SubscriptionGroupMember(group: 'g1', profile: '1')],
        tweets: [SavedTweet(id: 't1', user: 'dogs', content: '{}', folderId: 'f1')],
        savedTweetFolders: [
          SavedTweetFolder(id: 'f1', name: 'Reading', position: 2, createdAt: DateTime(2026, 9, 4, 9))
        ],
        likedTweets: [LikedTweet(id: 'l1', user: 'dogs', content: '{}')],
        accounts: [Account(id: 'a1', authHeader: '{}', screenName: 'me')],
      );

  T onlyRow<T>(List<T>? rows, String section) {
    expect(rows, isNotNull,
        reason: 'The $section section should survive the export and the import');
    expect(rows, hasLength(1),
        reason: 'The backup built above holds one $section row, so exactly one should come back');
    return rows!.single;
  }

  group('SettingsData.fromJson()', () {
    test('Should keep every section written by toJson', () {
      final restored = SettingsData.fromJson(jsonDecode(jsonEncode(full().toJson())));

      expect(restored.settings, {'theme.mode': 'dark'},
          reason: 'The settings go straight back into PrefService, so they should survive. '
              'Losing them resets every choice the user made');
      expect(onlyRow(restored.searchSubscriptions, 'search subscription').id, '#flutter',
          reason: 'Search subscriptions and user subscriptions are two different tables, and both '
              'should come back');
      final subscription = onlyRow(restored.userSubscriptions, 'user subscription');
      expect(subscription.screenName, 'dogs',
          reason: 'The feed searches with this name, so it should survive. Without it the account '
              'comes back with no tweets');
      expect(subscription.verified, isTrue,
          reason: 'True and false travel as numbers in the backup file, and should be read back '
              'as booleans. Otherwise every account comes back as not verified');
      expect(onlyRow(restored.subscriptionGroups, 'subscription group').name, 'Pets',
          reason: 'The group name is shown as a tab title on the home screen, so it should '
              'survive');
      expect(onlyRow(restored.subscriptionGroupMembers, 'group member').group, 'g1',
          reason: 'These rows are what put accounts inside a group, so they should survive. '
              'Without them every group comes back empty');
      expect(onlyRow(restored.tweets, 'saved tweet').folderId, 'f1',
          reason: 'Saved tweets and their folders are two sections, and this field is the link '
              'between them, so it should survive');
      expect(onlyRow(restored.savedTweetFolders, 'saved tweet folder').position, 2,
          reason: 'The position field holds the order the user gave to their folders, so it '
              'should survive');
      expect(onlyRow(restored.likedTweets, 'liked tweet').id, 'l1',
          reason: 'Liked tweets are a separate table from saved tweets and should not be mixed up '
              'with them');
      expect(onlyRow(restored.accounts, 'account').id, 'a1',
          reason: 'Keeping the accounts is the main reason to export, so they should survive. '
              'Without them the user has to log in again on the new device');
    });

    test('Should leave a missing section as null and not as an empty list', () {
      final restored = SettingsData.fromJson(jsonDecode('{"settings": {}}'));

      expect(restored.tweets, isNull,
          reason: 'The import only writes a table when its section is not null. An empty list and '
              'a missing section should stay different, otherwise importing a partial backup '
              'erases the tables it does not contain');
      expect(restored.accounts, isNull,
          reason: 'The same rule should hold for accounts, where erasing the table would log the '
              'user out');
    });

    test('Should read a backup made by an older build with no accounts section', () {
      final old = full().toJson()..remove('accounts');

      expect(SettingsData.fromJson(jsonDecode(jsonEncode(old))).accounts, isNull,
          reason: 'Backups made before multi account support have no accounts key, and should '
              'still import instead of throwing');
    });

    test('Should leave the group member count out of the backup', () {
      final exported = full().toJson();
      final groups = exported['subscriptionGroups'] as List;

      expect(groups.single, isNot(contains('number_of_members')),
          reason: 'The import feeds each exported row straight to batch.insert, and '
              'subscription_group has no number_of_members column, so writing the key would make '
              'every import fail. The count is a COUNT over the members table and should be '
              'computed again when the groups are loaded');
      expect(SettingsData.fromJson(jsonDecode(jsonEncode(exported)))
          .subscriptionGroups?.single.numberOfMembers, 0,
          reason: 'Nothing carries the count through the backup, so it should come back at 0 and '
              'be filled in by the group query');
    });

    test('Should restore the order and the enabled home tabs, group tabs included', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await PrefServiceShared.init(prefix: 'pref_');
      final backup = full().toJson()
        ..['settings'] = {
          optionHomePages: ['group-g1', 'feed', 'saved'],
        };
      final restored = SettingsData.fromJson(jsonDecode(jsonEncode(backup)));

      await prefs.fromMap(restored.settings!);
      final home = HomeModel(prefs, GroupsModel(prefs)..update(restored.subscriptionGroups!));
      await home.loadPages();

      expect(home.state.where((page) => page.selected).map((page) => page.id), ['group-g1', 'feed', 'saved'],
          reason: 'PrefService drops a list that is not a List<String> without any error, so the '
              'home tabs of the backup, with the tab of the imported group first, should be the '
              'ones shown and in the same order');
    });
  });
}
