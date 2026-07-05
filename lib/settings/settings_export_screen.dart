import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/settings/_data.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:intl/intl.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';

class SettingsExportScreen extends StatefulWidget {
  const SettingsExportScreen({super.key});

  @override
  State<SettingsExportScreen> createState() => _SettingsExportScreenState();
}

class _SettingsExportScreenState extends State<SettingsExportScreen> {
  bool _exportSettings = false;
  bool _exportSubscriptions = false;
  bool _exportSubscriptionGroups = false;
  bool _exportSubscriptionGroupMembers = false;
  bool _exportTweets = false;
  bool _exportSavedFolders = false;
  bool _exportLikedTweets = false;
  bool _exportAccounts = false;

  void toggleExportSubscriptionGroupMembersIfRequired() {
    if (_exportSubscriptionGroupMembers && (!_exportSubscriptions || !_exportSubscriptionGroups)) {
      setState(() {
        _exportSubscriptionGroupMembers = false;
      });
    }
  }

  void toggleExportSettings() {
    setState(() {
      _exportSettings = !_exportSettings;
    });
  }

  void toggleExportSubscriptions() {
    setState(() {
      _exportSubscriptions = !_exportSubscriptions;
    });

    toggleExportSubscriptionGroupMembersIfRequired();
  }

  void toggleExportSubscriptionGroups() {
    setState(() {
      _exportSubscriptionGroups = !_exportSubscriptionGroups;
    });

    toggleExportSubscriptionGroupMembersIfRequired();
  }

  void toggleExportSubscriptionGroupMembers() {
    setState(() {
      _exportSubscriptionGroupMembers = !_exportSubscriptionGroupMembers;
    });
  }

  void toggleExportTweets() {
    setState(() {
      _exportTweets = !_exportTweets;
    });
  }

  void toggleExportSavedFolders() {
    setState(() {
      _exportSavedFolders = !_exportSavedFolders;
    });
  }

  void toggleExportLikedTweets() {
    setState(() {
      _exportLikedTweets = !_exportLikedTweets;
    });
  }

  void toggleExportAccounts() {
    setState(() {
      _exportAccounts = !_exportAccounts;
    });
  }

  bool noExportOptionSelected() {
    return !(_exportSettings ||
        _exportSubscriptions ||
        _exportSubscriptionGroups ||
        _exportSubscriptionGroupMembers ||
        _exportTweets ||
        _exportSavedFolders ||
        _exportLikedTweets ||
        _exportAccounts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).export),
      ),
      floatingActionButton: noExportOptionSelected()
          ? null
          : FloatingActionButton(
              child: const Icon(Icons.save),
              onPressed: () async {
                var groupModel = context.read<GroupsModel>();
                var savedTweetFolderModel = context.read<SavedTweetFolderModel>();
                var likedTweetModel = context.read<LikedTweetModel>();
                await groupModel.reloadGroups();

                var subscriptionsModel = context.read<SubscriptionsModel>();
                await subscriptionsModel.reloadSubscriptions();

                var savedTweetModel = context.read<SavedTweetModel>();
                await savedTweetModel.listSavedTweets();

                await savedTweetFolderModel.listFolders();

                await likedTweetModel.listLikedTweets();

                List<Account>? accounts = _exportAccounts ? await getAccounts() : null;

                var prefs = PrefService.of(context);

                // TODO: Check exporting
                var settings = _exportSettings ? prefs.toMap() : null;

                var subscriptions = _exportSubscriptions ? subscriptionsModel.state : null;

                var subscriptionGroups = _exportSubscriptionGroups ? groupModel.state : null;

                var subscriptionGroupMembers =
                    _exportSubscriptionGroupMembers ? await groupModel.listGroupMembers() : null;

                var tweets = _exportTweets ? savedTweetModel.state : null;

                var savedTweetFolders = _exportSavedFolders ? savedTweetFolderModel.state : null;

                var likedTweets = _exportLikedTweets ? likedTweetModel.state : null;

                var data = SettingsData(
                    settings: settings,
                    searchSubscriptions: subscriptions?.whereType<SearchSubscription>().toList(),
                    userSubscriptions: subscriptions?.whereType<UserSubscription>().toList(),
                    subscriptionGroups: subscriptionGroups,
                    subscriptionGroupMembers: subscriptionGroupMembers,
                    tweets: tweets,
                    savedTweetFolders: savedTweetFolders,
                    likedTweets: likedTweets,
                    accounts: accounts);

                var exportData = jsonEncode(data.toJson());

                var dateFormat = DateFormat('yyyy-MM-dd');
                var fileName = 'quax-${dateFormat.format(DateTime.now())}.json';

                // This platform can support the directory picker, so display it
                var path = await FlutterFileDialog.saveFile(
                    params:
                        SaveFileDialogParams(fileName: fileName, data: Uint8List.fromList(utf8.encode(exportData))));
                if (path != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        L10n.of(context).data_exported_to_fileName(fileName),
                      ),
                    ),
                  );
                }
              },
            ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
              child: SingleChildScrollView(
                  child: Column(
            children: [
              CheckboxListTile(
                  value: _exportSettings,
                  title: Text(L10n.of(context).export_settings),
                  onChanged: (v) => toggleExportSettings()),
              CheckboxListTile(
                  value: _exportSubscriptions,
                  title: Text(L10n.of(context).export_subscriptions),
                  onChanged: (v) => toggleExportSubscriptions()),
              CheckboxListTile(
                  value: _exportSubscriptionGroups,
                  title: Text(L10n.of(context).export_subscription_groups),
                  onChanged: (v) => toggleExportSubscriptionGroups()),
              CheckboxListTile(
                  value: _exportSubscriptionGroupMembers,
                  title: Text(L10n.of(context).export_subscription_group_members),
                  onChanged: _exportSubscriptions && _exportSubscriptionGroups
                      ? (v) => toggleExportSubscriptionGroupMembers()
                      : null),
              CheckboxListTile(
                  value: _exportTweets,
                  title: Text(L10n.of(context).export_tweets),
                  onChanged: (v) => toggleExportTweets()),
              CheckboxListTile(
                  value: _exportSavedFolders,
                  title: Text(L10n.of(context).export_saved_folders),
                  onChanged: (v) => toggleExportSavedFolders()),
              CheckboxListTile(
                  value: _exportLikedTweets,
                  title: Text(L10n.of(context).export_liked_posts),
                  onChanged: (v) => toggleExportLikedTweets()),
              CheckboxListTile(
                  value: _exportAccounts,
                  title: Text(L10n.of(context).export_accounts),
                  subtitle: Text(L10n.of(context).export_accounts_details),
                  onChanged: (v) => toggleExportAccounts()),
            ],
          ))),
        ],
      ),
    );
  }
}
