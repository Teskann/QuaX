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
import 'package:quax/settings/_data.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../group/open_feed.dart';
import '../ui/pump_app.dart';

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
    final backup = File('${Directory.systemTemp.createTempSync('quax-backup').path}/backup.json')
      ..writeAsStringSync(
        jsonEncode(
          SettingsData(
            settings: {optionSubscriptionOrderByField: 'created_at'},
            subscriptions: [flutterDev, olderAccount],
            subscriptionGroups: null,
            subscriptionGroupMembers: null,
            tweets: null,
            savedTweetFolders: null,
            likedTweets: null,
            accounts: null,
          ).toJson(),
        ),
      );
    await pumpInApp(
      tester,
      const Text('onboarding'),
      prefs: subscriptionPrefDefaults,
      aboveApp: (app) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ImportDataModel()),
          Provider(create: (c) => GroupsModel()),
          Provider(
            lazy: false,
            create: (c) => subscriptions = SubscriptionsModel(PrefService.of(c, listen: false), c.read<GroupsModel>()),
          ),
          Provider(create: (_) => SavedTweetFolderModel()),
          Provider(create: (_) => LikedTweetModel()),
        ],
        child: app,
      ),
    );

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
}
