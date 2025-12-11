import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/home_screen.dart';
import 'package:quax/utils/iterables.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';

String getFlavor() {
  const flavor = String.fromEnvironment('app.flavor');

  if (flavor == '') {
    return 'fdroid';
  }

  return flavor;
}

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

languagePicker() {
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

  PrefDialog _createXClientTransactionIdDialog(BuildContext context, BasePrefService prefs) {
    var mediaQuery = MediaQuery.of(context);
    final controller = TextEditingController(
        text: prefs.get(optionXClientTransactionIdProvider) ?? optionXClientTransactionIdProviderDefaultDomain);

    return PrefDialog(
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).cancel)),
          TextButton(
              onPressed: () async {
                await prefs.set(optionXClientTransactionIdProvider,
                    controller.text.isEmpty ? optionXClientTransactionIdProviderDefaultDomain : controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: Text(L10n.of(context).save))
        ],
        title: Text(L10n.of(context).x_client_transaction_id_provider),
        children: [
          SizedBox(
            width: mediaQuery.size.width,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(hintText: optionXClientTransactionIdProviderDefaultDomain),
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
              title: Text(L10n.of(context).media_size),
              subtitle: Text(
                L10n.of(context).save_bandwidth_using_smaller_images,
              ),
              pref: optionMediaSize,
              items: [
                DropdownMenuItem(
                  value: 'disabled',
                  child: Text(L10n.of(context).disabled),
                ),
                DropdownMenuItem(
                  value: 'thumb',
                  child: Text(L10n.of(context).thumbnail),
                ),
                DropdownMenuItem(
                  value: 'small',
                  child: Text(L10n.of(context).small),
                ),
                DropdownMenuItem(
                  value: 'medium',
                  child: Text(L10n.of(context).medium),
                ),
                DropdownMenuItem(
                  value: 'large',
                  child: Text(L10n.of(context).large),
                ),
              ]),
          PrefSwitch(
            pref: optionUseAbsoluteTimestamp,
            title: Text(L10n.of(context).use_absolute_timestamp),
            subtitle: Text(L10n.of(context).use_absolute_timestamp_description),
          ),
          PrefSwitch(
            pref: optionMediaDefaultMute,
            title: Text(L10n.of(context).mute_videos),
            subtitle: Text(L10n.of(context).mute_video_description),
          ),
          PrefSwitch(
            pref: optionMediaDefaultLoop,
            title: Text(L10n.of(context).loop_videos),
            subtitle: Text(L10n.of(context).loop_videos_description),
          ),
          PrefSwitch(
            pref: optionMediaDefaultAutoPlay,
            title: Text(L10n.of(context).autoplay_videos),
            subtitle: Text(L10n.of(context).autoplay_videos_description),
          ),
          PrefSwitch(
            pref: optionMediaBackgroundPlayback,
            title: Text(L10n.of(context).allow_background_play),
            subtitle: Text(L10n.of(context).allow_background_play_description),
          ),
          PrefSwitch(
            pref: optionMediaAllowBackgroundPlayOtherApps,
            title: Text(L10n.of(context).allow_background_play_other_apps),
            subtitle: Text(L10n.of(context).allow_background_play_other_apps_description),
          ),
          PrefCheckbox(
            title: Text(L10n.of(context).hide_sensitive_tweets),
            subtitle: Text(L10n.of(context).whether_to_hide_tweets_marked_as_sensitive),
            pref: optionTweetsHideSensitive,
          ),
          PrefDialogButton(
            title: Text(L10n.of(context).share_base_url),
            subtitle: Text(L10n.of(context).share_base_url_description),
            dialog: _createShareBaseDialog(context, prefs),
          ),
          PrefSwitch(
            title: Text(L10n.of(context).disable_screenshots),
            subtitle: Text(L10n.of(context).disable_screenshots_hint),
            pref: optionDisableScreenshots,
          ),
          DownloadTypeSetting(
            prefs: prefs,
          ),
          PrefSwitch(
            title: Text(L10n.of(context).activate_non_confirmation_bias_mode_label),
            pref: optionNonConfirmationBiasMode,
            subtitle: Text(L10n.of(context).activate_non_confirmation_bias_mode_description),
          ),
          PrefDialogButton(
            title: Text(L10n.of(context).x_client_transaction_id_provider),
            subtitle: Text(L10n.of(context).x_client_transaction_id_provider_description),
            dialog: _createXClientTransactionIdDialog(context, prefs),
          ),
          PrefSwitch(
            title: Text(L10n.of(context).disable_warnings_for_unrelated_posts_in_feed),
            subtitle: Text(L10n.of(context).disable_warnings_for_unrelated_posts_in_feed_description),
            pref: optionDisableWarningsForUnrelatedPostsInFeed,
          ),
        ]),
      ),
    );
  }
}

class DownloadTypeSetting extends StatefulWidget {
  final BasePrefService prefs;

  const DownloadTypeSetting({super.key, required this.prefs});

  @override
  DownloadTypeSettingState createState() => DownloadTypeSettingState();
}

class DownloadTypeSettingState extends State<DownloadTypeSetting> {
  @override
  Widget build(BuildContext context) {
    var downloadPath = widget.prefs.get<String>(optionDownloadPath) ?? '';

    return Column(
      children: [
        PrefDropdown(
          onChange: (value) {
            setState(() {});
          },
          fullWidth: false,
          title: Text(L10n.current.download_handling),
          subtitle: Text(L10n.current.download_handling_description),
          pref: optionDownloadType,
          items: [
            DropdownMenuItem(value: optionDownloadTypeAsk, child: Text(L10n.current.download_handling_type_ask)),
            DropdownMenuItem(
                value: optionDownloadTypeDirectory, child: Text(L10n.current.download_handling_type_directory)),
          ],
        ),
        if (widget.prefs.get(optionDownloadType) == optionDownloadTypeDirectory)
          PrefButton(
            onTap: () async {
              String? directoryPath = await FilePicker.platform.getDirectoryPath();

              if (directoryPath == null) {
                return;
              }
              // TODO: Gross. Figure out how to re-render automatically when the preference changes
              setState(() {
                widget.prefs.set(optionDownloadPath, directoryPath);
              });
            },
            title: Text(L10n.current.download_path),
            subtitle: Text(
              downloadPath.isEmpty ? L10n.current.not_set : downloadPath,
            ),
            child: Text(L10n.current.choose),
          )
      ],
    );
  }
}
