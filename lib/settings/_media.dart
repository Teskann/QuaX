import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';

class SettingsMediaFragment extends StatelessWidget {
  const SettingsMediaFragment({super.key});

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.current.media)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(children: [
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
          DownloadTypeSetting(
            prefs: prefs,
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
              String? directoryPath = await FilePicker.getDirectoryPath();

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
