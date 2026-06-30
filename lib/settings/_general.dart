import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/_feed.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/utils/iterables.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';

class SettingLocale {
  final String code;
  final String name;

  SettingLocale(this.code, this.name);

  factory SettingLocale.fromLocale(Locale locale) {
    var code = locale.toLanguageTag().replaceAll('-', '_');
    var name = LocaleNamesLocalizationsDelegate.nativeLocaleNames[code] ?? code;

    return SettingLocale(code, name);
  }
}

PrefDropdown<String> languagePicker() {
  return PrefDropdown(
      fullWidth: false,
      title: Text(L10n.current.language),
      subtitle: Text(L10n.current.language_subtitle),
      pref: optionLocale,
      items: [
        DropdownMenuItem(value: optionLocaleDefault, child: Text(L10n.current.system)),
        ...L10n.delegate.supportedLocales
            .map((e) => SettingLocale.fromLocale(e))
            .sorted((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()))
            .map((e) => DropdownMenuItem(value: e.code, child: Text(e.name)))
      ]);
}

class SettingsGeneralFragment extends StatelessWidget {
  static final log = Logger('SettingsGeneralFragment');

  const SettingsGeneralFragment({super.key});

  PrefDialog _createShareBaseDialog(BuildContext context, BasePrefService prefs) {
    var mediaQuery = MediaQuery.of(context);

    final controller = TextEditingController(text: prefs.get(optionShareBaseUrl));

    return PrefDialog(
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).cancel)),
          TextButton(
              onPressed: () async {
                await prefs.set(optionShareBaseUrl, controller.text);

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(L10n.of(context).save))
        ],
        title: Text(L10n.of(context).share_base_url),
        children: [
          SizedBox(
            width: mediaQuery.size.width,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'https://x.com'),
            ),
          )
        ]);
  }

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.current.general)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(children: [
          languagePicker(),
          PrefSwitch(
            title: Text(L10n.of(context).should_check_for_updates_label),
            pref: optionShouldCheckForUpdates,
            subtitle: Text(L10n.of(context).should_check_for_updates_description),
          ),
          PrefSwitch(
            title: Text(L10n.of(context).option_confirm_close_label),
            subtitle: Text(L10n.of(context).option_confirm_close_description),
            pref: optionConfirmClose,
          ),
          PrefSwitch(
            title: Text(L10n.of(context).disable_screenshots),
            subtitle: Text(L10n.of(context).disable_screenshots_hint),
            pref: optionDisableScreenshots,
          ),
          PrefDropdown(
              fullWidth: false,
              title: Text(L10n.of(context).default_tab),
              subtitle: Text(
                L10n.of(context).which_tab_is_shown_when_the_app_opens,
              ),
              pref: optionHomeInitialTab,
              items: defaultHomePages
                  .map((e) => DropdownMenuItem(value: e.id, child: Text(e.titleBuilder(context))))
                  .toList()),
          PrefDropdown(
              fullWidth: false,
              title: Text(L10n.of(context).default_feed_tab),
              subtitle: Text(
                L10n.of(context).default_feed_tab_description,
              ),
              pref: optionHomeDefaultFeedTab,
              items: feedTabs
                  .map((e) => DropdownMenuItem(value: e.id.name, child: Text(e.titleBuilder(context))))
                  .toList()),
          PrefDropdown(
              fullWidth: false,
              title: Text(L10n.of(context).default_profile_tab),
              subtitle: Text(
                L10n.of(context).default_profile_tab_description,
              ),
              pref: optionDefaultProfileTab,
              items: profileTabs
                  .map((e) => DropdownMenuItem(value: e.id.name, child: Text(e.titleBuilder(context))))
                  .toList()),
          PrefDialogButton(
            title: Text(L10n.of(context).share_base_url),
            subtitle: Text(L10n.of(context).share_base_url_description),
            dialog: _createShareBaseDialog(context, prefs),
          ),
        ]),
      ),
    );
  }
}
