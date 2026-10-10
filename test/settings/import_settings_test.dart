import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/settings/_data.dart';

void main() {
  const defaultTabs = ['feed', 'subscriptions', 'trending', 'saved'];

  BasePrefService prefsWith(List<String> tabs) =>
      PrefServiceCache(defaults: {optionHomePages: tabs, optionHomeInitialTab: 'feed', optionTextScaleFactor: 1.1});

  /// What a backup file holds once written and read back, the way the export and the import do it
  Map<String, dynamic> throughBackupFile(BasePrefService prefs) {
    final backup = SettingsData(
        settings: prefs.toMap(),
        searchSubscriptions: null,
        userSubscriptions: null,
        subscriptionGroups: null,
        subscriptionGroupMembers: null,
        tweets: null,
        savedTweetFolders: null,
        likedTweets: null,
        accounts: null);
    return SettingsData.fromJson(jsonDecode(jsonEncode(backup.toJson()))).settings!;
  }

  test('Should keep the order and the enabled home tabs through an export and an import', () async {
    final exported = throughBackupFile(prefsWith(['saved', 'group-3', 'feed']));
    final restored = prefsWith(defaultTabs);

    await importSettings(restored, exported);

    expect(restored.getStringList(optionHomePages), ['saved', 'group-3', 'feed'],
        reason: 'The tabs should come back in the order the user gave, without the ones that were disabled');
  });

  test('Should keep the other settings of a backup next to the home tabs', () async {
    final exported = throughBackupFile(prefsWith(['saved', 'feed'])..set(optionHomeInitialTab, 'saved'));
    final restored = prefsWith(defaultTabs);

    await importSettings(restored, exported);

    expect(restored.get(optionHomeInitialTab), 'saved', reason: 'Plain settings should still be imported');
    expect(restored.get(optionTextScaleFactor), 1.1, reason: 'Numbers should still be imported');
  });

  test('Should leave the home tabs unchanged when the backup comes from a build without them', () async {
    final restored = prefsWith(['saved', 'feed']);

    await importSettings(restored, {optionHomeInitialTab: 'saved'});

    expect(restored.getStringList(optionHomePages), ['saved', 'feed'],
        reason: 'Older backups have no home tabs, so the tabs of the user should not be reset');
    expect(restored.get(optionHomeInitialTab), 'saved', reason: 'The rest of the old backup should be imported');
  });

  test('Should keep the current home tabs when the backup holds something else than a list of ids', () async {
    for (final malformed in <Object?>['feed', 42, ['feed', 1], [null], {'feed': true}, null]) {
      final restored = prefsWith(['saved', 'feed']);

      await importSettings(restored, {optionHomePages: malformed, optionHomeInitialTab: 'saved'});

      expect(restored.getStringList(optionHomePages), ['saved', 'feed'],
          reason: 'A damaged value ($malformed) should not replace the tabs, nor crash the import');
      expect(restored.get(optionHomeInitialTab), 'saved',
          reason: 'A damaged value should not stop the other settings from being imported');
    }
  });

  test('Should import an empty list of home tabs', () async {
    final restored = prefsWith(defaultTabs);

    await importSettings(restored, {optionHomePages: <dynamic>[]});

    expect(restored.getStringList(optionHomePages), isEmpty, reason: 'No tab enabled is a valid choice to restore');
  });

  test('Should import a setting the app does not hold yet', () async {
    final restored = prefsWith(defaultTabs);

    await importSettings(restored, {'new.setting': true});

    expect(restored.get('new.setting'), isTrue, reason: 'Without a current value there is nothing to conflict with');
  });

  test('Should keep the current value when the backup holds a value of another kind', () async {
    final restored = prefsWith(defaultTabs);

    await importSettings(restored, {optionHomeInitialTab: ['saved'], optionTextScaleFactor: 'big'});

    expect(restored.get(optionHomeInitialTab), 'feed', reason: 'A list cannot replace a text setting');
    expect(restored.get(optionTextScaleFactor), 1.1, reason: 'A text cannot replace a number setting');
  });
}
