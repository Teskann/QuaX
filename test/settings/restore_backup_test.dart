import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/settings/_data.dart';
import 'package:quax/settings/encrypted_accounts.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../client/fresh_accounts.dart';
import '../group/open_feed.dart';
import '../subscriptions/fixtures.dart' show pumpUntilFound, pumpUntilGone;
import '../ui/pump_app.dart';

File backupFile(
        {Map<String, dynamic>? settings,
        List<Subscription>? subscriptions,
        List<SavedTweet>? tweets,
        List<Account>? plainAccounts,
        Map<String, dynamic>? encryptedAccounts}) =>
    File('${Directory.systemTemp.createTempSync('quax-backup').path}/backup.json')
      ..writeAsStringSync(
        jsonEncode(
          SettingsData(
            settings: settings,
            subscriptions: subscriptions,
            subscriptionGroups: null,
            subscriptionGroupMembers: null,
            tweets: tweets,
            savedTweetFolders: null,
            likedTweets: null,
            plainAccounts: plainAccounts,
            encryptedAccounts: encryptedAccounts,
          ).toJson(),
        ),
      );

/// Pumps [body] under the models a restore reloads, and gives them to [onModels] as they are created.
Future<void> pumpRestorer(WidgetTester tester, Widget body,
        {void Function(SubscriptionsModel subscriptions, SavedTweetModel savedTweets)? onModels}) =>
    pumpInApp(
      tester,
      body,
      prefs: subscriptionPrefDefaults,
      aboveApp: (app) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ImportDataModel()),
          Provider(create: (c) => GroupsModel()),
          Provider(create: (_) => SavedTweetModel()),
          Provider(
            lazy: false,
            create: (c) {
              final subscriptions = SubscriptionsModel(PrefService.of(c, listen: false), c.read<GroupsModel>());
              onModels?.call(subscriptions, c.read<SavedTweetModel>());
              return subscriptions;
            },
          ),
          Provider(create: (_) => SavedTweetFolderModel()),
          Provider(create: (_) => LikedTweetModel()),
        ],
        child: app,
      ),
    );

void main() {
  useFreshDatabase();
  useFreshAccounts();

  testWidgets('Should show the restored subscriptions in the restored order, even when restoring closes the page '
      'that started it', (tester) async {
    late SubscriptionsModel subscriptions;
    final olderAccount = UserSubscription.fromMap({
      ...flutterDev.toMap(),
      'id': 'older',
      'name': 'Zed',
      'created_at': '2020-01-01 00:00:00',
    });
    final backup = backupFile(
      settings: {optionSubscriptionOrderByField: 'created_at'},
      subscriptions: [flutterDev, olderAccount],
    );
    await pumpRestorer(tester, const Text('onboarding'), onModels: (model, _) => subscriptions = model);

    final context = tester.element(find.text('onboarding'));
    late Future<void> restoring;
    await tester.runAsync(() async {
      // The app has shown the subscriptions, in its own order, before the backup is restored
      await subscriptions.reloadSubscriptions();
      restoring = importFromFile(context, backup);
    });
    // The onboarding is replaced by the home page as soon as the restored settings say it was done
    await pumpInApp(tester, const Text('home'), aboveApp: (app) => app, settle: false);
    await tester.runAsync(() => restoring);

    expect(subscriptions.state.map((s) => s.id), [
      olderAccount.id,
      flutterDev.id,
    ], reason: 'The restored subscriptions should show without restarting the app, sorted as the backup says');
  });

  testWidgets('Should list the saved posts of two backups by the date they were first saved', (tester) async {
    late SavedTweetModel savedTweets;
    SavedTweet saved(String id, String savedAt) =>
        SavedTweet(id: id, user: 'dogs', content: '{}', savedAt: DateTime.parse(savedAt));
    final earlier = backupFile(tweets: [saved('first', '2026-01-01T10:00:00Z'), saved('third', '2026-03-01T10:00:00Z')]);
    final later = backupFile(tweets: [saved('second', '2026-02-01T10:00:00Z'), saved('third', '2026-04-01T10:00:00Z')]);
    await pumpRestorer(tester, const Text('saved'), onModels: (_, model) => savedTweets = model);

    final context = tester.element(find.text('saved'));
    await tester.runAsync(() async {
      await importFromFile(context, earlier);
      await importFromFile(context, later);
    });

    expect(savedTweets.state.map((tweet) => tweet.id), ['third', 'second', 'first'],
        reason: 'The saved posts should show without restarting the app, newest save first, by the date each was '
            'saved and not by when its backup was imported');
    expect(savedTweets.state.first.savedAt, DateTime.utc(2026, 3, 1, 10),
        reason: 'A post found in both backups should keep the date it was first saved');
  });

  group('A backup with encrypted accounts', () {
    final account = Account(id: 'a1', authHeader: '{"Cookie":"auth_token=secret"}', screenName: 'me');
    late SubscriptionsModel subscriptions;
    late Future<void> restoring;

    /// Starts restoring a backup of [encryptedAccounts], and waits for the password dialog.
    Future<void> startRestoringBackup(WidgetTester tester, Map<String, dynamic> encryptedAccounts) async {
      final backup = backupFile(subscriptions: [flutterDev], encryptedAccounts: encryptedAccounts);
      await pumpRestorer(tester, const Text('settings'), onModels: (model, _) => subscriptions = model);
      await tester.runAsync(() async {
        restoring = importFromFile(tester.element(find.text('settings')), backup);
      });
      await pumpUntilFound(tester, find.text('Encrypted accounts'));
    }

    /// Starts restoring a backup of [account] encrypted with "correct horse", and waits for the password dialog.
    Future<void> startRestoring(WidgetTester tester) async {
      final encrypted = await tester.runAsync(() => encryptAccounts([account], 'correct horse'));
      await startRestoringBackup(tester, encrypted!.toJson());
    }

    Future<void> submitPassword(WidgetTester tester, String password) async {
      await tester.enterText(find.byType(TextField), password);
      await tester.tap(find.text('Import'));
      await tester.pump();
    }

    testWidgets('Should restore the accounts once the right password is entered', (tester) async {
      await startRestoring(tester);

      await submitPassword(tester, 'wrong horse');
      await pumpUntilFound(tester, find.text('Wrong password'));
      await submitPassword(tester, 'correct horse');
      await pumpUntilGone(tester, find.text('Encrypted accounts'));
      await tester.runAsync(() => restoring);

      final accounts = await tester.runAsync(getAccounts);
      expect(accounts!.single.authHeader, account.authHeader,
          reason: 'After a wrong password, the right one should still log the user in on the new device');
    });

    testWidgets('Should restore the rest of the backup when the accounts are skipped', (tester) async {
      await startRestoring(tester);

      await tester.tap(find.text('Skip accounts'));
      await tester.pump();
      await tester.runAsync(() => restoring);

      expect(await tester.runAsync(getAccounts), isEmpty,
          reason: 'A user who lost the password should not be stuck: the accounts are left out');
      expect(subscriptions.state.map((s) => s.id), [flutterDev.id],
          reason: 'Skipping the accounts should still restore everything else in the backup');
    });

    testWidgets('Should let the user skip the accounts of a backup that asks for too much memory', (tester) async {
      final encrypted = await tester.runAsync(() => encryptAccounts([account], 'correct horse'));
      final json = encrypted!.toJson();
      await startRestoringBackup(tester, {
        ...json,
        'kdf': {...json['kdf'], 'memory': 1 << 30}
      });

      await submitPassword(tester, 'correct horse');
      await pumpUntilFound(tester, find.text('The accounts of this backup cannot be read'));
      await tester.tap(find.text('Skip accounts'));
      await tester.pump();
      await tester.runAsync(() => restoring);

      expect(subscriptions.state.map((s) => s.id), [flutterDev.id],
          reason: 'A backup anyone could have edited must neither freeze the app nor stop the rest from restoring');
    });
  });

  testWidgets('Should save the accounts before the restored settings open the home page', (tester) async {
    final account = Account(id: 'a1', authHeader: '{"Cookie":"auth_token=secret"}', screenName: 'me');
    final backup = backupFile(settings: {optionOnboardingDone: true}, plainAccounts: [account]);
    await pumpRestorer(tester, const Text('onboarding'));
    final context = tester.element(find.text('onboarding'));
    Future<List<Account>>? accountsWhenHomeOpens;
    PrefService.of(context, listen: false)
        .addKeyListener(optionOnboardingDone, () => accountsWhenHomeOpens ??= getAccounts());

    await tester.runAsync(() => importFromFile(context, backup));

    expect(accountsWhenHomeOpens, isNotNull, reason: 'The backup should mark the onboarding as done');
    final accounts = await tester.runAsync(() => accountsWhenHomeOpens!);
    expect(accounts!.map((a) => a.id), ['a1'],
        reason: 'The restored settings open the home page when the backup is imported from the onboarding. Its first '
            'requests must already use the accounts of the backup, as X answers 404 to most of them without one');
  });

  testWidgets('Should restore the accounts of a backup made before they were encrypted', (tester) async {
    final account = Account(id: 'a1', authHeader: '{"Cookie":"auth_token=secret"}', screenName: 'me');
    final backup = backupFile(plainAccounts: [account]);
    await pumpRestorer(tester, const Text('settings'));

    await tester.runAsync(() => importFromFile(tester.element(find.text('settings')), backup));

    final accounts = await tester.runAsync(getAccounts);
    expect(accounts!.single.authHeader, account.authHeader,
        reason: 'Older backups hold the accounts unencrypted, and should still log the user in without a password');
  });
}
