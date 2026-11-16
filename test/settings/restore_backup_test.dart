import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/settings/_data.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../group/open_feed.dart';
import '../ui/pump_app.dart';

File backupFile(
        {Map<String, dynamic>? settings, List<Subscription>? subscriptions, List<SavedTweet>? tweets}) =>
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
            accounts: null,
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
}
