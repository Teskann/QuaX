import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/home_model.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class SettingsData {
  final Map<String, dynamic>? settings;
  final List<SearchSubscription>? searchSubscriptions;
  final List<UserSubscription>? userSubscriptions;
  final List<SubscriptionGroup>? subscriptionGroups;
  final List<SubscriptionGroupMember>? subscriptionGroupMembers;
  final List<SavedTweet>? tweets;
  final List<SavedTweetFolder>? savedTweetFolders;
  final List<LikedTweet>? likedTweets;
  final List<Account>? accounts;

  SettingsData(
      {required this.settings,
      required this.searchSubscriptions,
      required this.userSubscriptions,
      required this.subscriptionGroups,
      required this.subscriptionGroupMembers,
      required this.tweets,
      required this.savedTweetFolders,
      required this.likedTweets,
      required this.accounts});

  factory SettingsData.fromJson(Map<String, dynamic> json) {
    return SettingsData(
        settings: json['settings'],
        searchSubscriptions: json['searchSubscriptions'] != null
            ? List.from(json['searchSubscriptions']).map((e) => SearchSubscription.fromMap(e)).toList()
            : null,
        userSubscriptions: json['subscriptions'] != null
            ? List.from(json['subscriptions']).map((e) => UserSubscription.fromMap(e)).toList()
            : null,
        subscriptionGroups: json['subscriptionGroups'] != null
            ? List.from(json['subscriptionGroups']).map((e) => SubscriptionGroup.fromMap(e)).toList()
            : null,
        subscriptionGroupMembers: json['subscriptionGroupMembers'] != null
            ? List.from(json['subscriptionGroupMembers']).map((e) => SubscriptionGroupMember.fromMap(e)).toList()
            : null,
        tweets: json['tweets'] != null ? List.from(json['tweets']).map((e) => SavedTweet.fromMap(e)).toList() : null,
        savedTweetFolders: json['savedTweetFolders'] != null
            ? List.from(json['savedTweetFolders']).map((e) => SavedTweetFolder.fromMap(e)).toList()
            : null,
        likedTweets: json['likedTweets'] != null
            ? List.from(json['likedTweets']).map((e) => LikedTweet.fromMap(e)).toList()
            : null,
        accounts: json['accounts'] != null ? List.from(json['accounts']).map((e) => Account.fromMap(e)).toList() : null);
  }

  Map<String, dynamic> toJson() {
    return {
      'settings': settings,
      'searchSubscriptions': searchSubscriptions?.map((e) => e.toMap()).toList(),
      'subscriptions': userSubscriptions?.map((e) => e.toMap()).toList(),
      'subscriptionGroups': subscriptionGroups?.map((e) => e.toMap()).toList(),
      'subscriptionGroupMembers': subscriptionGroupMembers?.map((e) => e.toMap()).toList(),
      'tweets': tweets?.map((e) => e.toMap()).toList(),
      'savedTweetFolders': savedTweetFolders?.map((e) => e.toMap()).toList(),
      'likedTweets': likedTweets?.map((e) => e.toMap()).toList(),
      'accounts': accounts?.map((e) => e.toMap()).toList()
    };
  }
}

/// A value as the preferences can hold it. JSON reads lists back as lists of objects, which the preferences refuse
Object? _storable(Object? value) => switch (value) {
      List() => value.every((e) => e is String) ? value.cast<String>().toList() : null,
      _ => value,
    };

bool _sameKind(Object? current, Object? value) =>
    current == null || (current is List ? value is List : current.runtimeType == value.runtimeType);

/// The [settings] of a backup that the preferences can take. What they cannot hold, or what is not of the kind they
/// hold now, is left out, so that a damaged value keeps the current one instead of breaking the app
Map<String, dynamic> restorableSettings(BasePrefService prefs, Map<String, dynamic> settings) => {
      for (final MapEntry(:key, :value) in settings.entries)
        if (_storable(value) case final storable? when _sameKind(prefs.get<dynamic>(key), storable)) key: storable,
    };

Future<void> importSettings(BasePrefService prefs, Map<String, dynamic> settings) =>
    prefs.fromMap(restorableSettings(prefs, settings));

Future<void> _importFromFile(BuildContext context, File file) async {
  var content = jsonDecode(file.readAsStringSync());

  var importModel = context.read<ImportDataModel>();
  var groupModel = context.read<GroupsModel>();
  var prefs = PrefService.of(context);

  var data = SettingsData.fromJson(content);

  var settings = data.settings;
  if (settings != null) {
    await importSettings(prefs, settings);
  }

  var dataToImport = <String, List<ToMappable>>{};

  var searchSubscriptions = data.searchSubscriptions;
  if (searchSubscriptions != null) {
    dataToImport[tableSearchSubscription] = searchSubscriptions;
  }

  var userSubscriptions = data.userSubscriptions;
  if (userSubscriptions != null) {
    dataToImport[tableSubscription] = userSubscriptions;
  }

  var subscriptionGroups = data.subscriptionGroups;
  if (subscriptionGroups != null) {
    dataToImport[tableSubscriptionGroup] = subscriptionGroups;
  }

  var subscriptionGroupMembers = data.subscriptionGroupMembers;
  if (subscriptionGroupMembers != null) {
    dataToImport[tableSubscriptionGroupMember] = subscriptionGroupMembers;
  }

  var tweets = data.tweets;
  if (tweets != null) {
    dataToImport[tableSavedTweet] = tweets;
  }

  var savedTweetFolders = data.savedTweetFolders;
  if (savedTweetFolders != null) {
    dataToImport[tableSavedTweetFolder] = savedTweetFolders;
  }

  var likedTweets = data.likedTweets;
  if (likedTweets != null) {
    dataToImport[tableLikedTweet] = likedTweets;
  }

  var accounts = data.accounts;
  if(accounts != null) {
    dataToImport[tableAccounts] = accounts;
  }

  await importModel.importData(dataToImport);
  await groupModel.reloadGroups();
  context.mounted ? await context.read<HomeModel>().loadPages() : null;
  context.mounted ? await context.read<SubscriptionsModel>().reloadSubscriptions() : null;
  context.mounted ? await context.read<SavedTweetFolderModel>().listFolders() : null;
  context.mounted ? await context.read<LikedTweetModel>().listLikedTweets() : null;

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L10n.of(context).data_imported_successfully),
    ));
  }
}

/// Whether a backup was picked and imported.
Future<bool> importBackup(BuildContext context) async {
  var path = await FlutterFileDialog.pickFile(params: const OpenFileDialogParams());
  if (path == null || !context.mounted) {
    return false;
  }
  await _importFromFile(context, File(path));
  return true;
}

class SettingsDataFragment extends StatelessWidget {
  static final log = Logger('SettingsDataFragment');

  const SettingsDataFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      PrefLabel(
        leading: const Icon(Icons.import_export),
        title: Text(L10n.of(context).import),
        subtitle: Text(L10n.of(context).import_data_from_another_device),
        onTap: () => importBackup(context),
      ),
      PrefLabel(
        leading: const Icon(Icons.save),
        title: Text(L10n.of(context).export),
        subtitle: Text(L10n.of(context).export_your_data),
        onTap: () => Navigator.pushNamed(context, routeSettingsExport),
      ),
    ]);
  }
}
