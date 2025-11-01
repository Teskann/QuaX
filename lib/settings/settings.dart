import 'dart:async';
import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/settings/_about.dart';
import 'package:quax/settings/_accessibility.dart';
import 'package:quax/settings/_account.dart';
import 'package:quax/settings/_data.dart';
import 'package:quax/settings/_general.dart';
import 'package:quax/settings/_home.dart';
import 'package:quax/settings/_theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  final String? initialPage;

  const SettingsScreen({super.key, this.initialPage});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo _packageInfo = PackageInfo(appName: '', packageName: '', version: '', buildNumber: '');

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      var packageInfo = await PackageInfo.fromPlatform();

      setState(() {
        _packageInfo = packageInfo;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var key = widget.key ?? const Key("Settings");
    var appVersion = 'v${_packageInfo.version}+${_packageInfo.buildNumber}';

    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).settings)),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          ListTile(
            title: Text(L10n.of(context).general),
            leading: Icon(Icons.miscellaneous_services),
            subtitle: Text(
              "${L10n.of(context).language}, ${L10n.of(context).should_check_for_updates_label}, ${L10n.of(context).default_tab}, ${L10n.of(context).media_size}, ${L10n.of(context).mute_videos}, ${L10n.of(context).hide_sensitive_tweets}, ${L10n.of(context).share_base_url}, ${L10n.of(context).disable_screenshots}, ${L10n.of(context).download_handling}, ${L10n.of(context).activate_non_confirmation_bias_mode_label}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsGeneralFragment()),
            ),
          ),
          ListTile(
            title: Text(L10n.of(context).account),
            leading: Icon(Icons.account_circle),
            subtitle: Text(
              L10n.of(context).account,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SettingsAccountFragment(
                        key: key,
                      )),
            ),
          ),
          ListTile(
            title: Text(L10n.of(context).home),
            leading: Icon(Icons.home),
            subtitle: Text(
              "${L10n.of(context).reset_home_pages}, ${L10n.of(context).home}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsHomeFragment()),
            ),
          ),
          ListTile(
            title: Text(L10n.of(context).theme),
            subtitle: Text(
              "${L10n.of(context).theme_mode}, ${L10n.of(context).theme}, ${L10n.of(context).true_black}, ${L10n.of(context).true_black_tweet_cards} ${L10n.of(context).show_navigation_labels}",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            leading: Icon(Icons.palette),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsThemeFragment()),
            ),
          ),
          ListTile(
            title: Text(L10n.of(context).accessibility),
            leading: Icon(Icons.settings_accessibility),
            subtitle: Text(
              L10n.of(context).disable_animations,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsAccessibilityFragment()),
            ),
          ),
          Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Column(children: [
                ListTile(
                  title: Text(
                    L10n.of(context).data,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SettingsDataFragment()
              ])),
          const SizedBox(
            height: 8.0,
          ),
          Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Column(children: [
                ListTile(
                  title: Text(
                    L10n.of(context).app_info,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                SettingsAboutFragment(
                  appVersion: appVersion,
                )
              ])),
        ],
      ),
    );
  }
}
