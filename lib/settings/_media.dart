import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';
import 'package:quax/ui/labeled_pref.dart';

class SettingsMediaFragment extends StatelessWidget {
  const SettingsMediaFragment({super.key});

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context);

    List<DropdownMenuItem<String>> qualityItems() => [
          DropdownMenuItem(value: 'thumb', child: Text(L10n.of(context).quality_low)),
          DropdownMenuItem(value: 'small', child: Text(L10n.of(context).quality_medium)),
          DropdownMenuItem(value: 'medium', child: Text(L10n.of(context).quality_high)),
          DropdownMenuItem(value: 'large', child: Text(L10n.of(context).quality_maximum)),
        ];

    return Scaffold(
      appBar: AppBar(title: Text(L10n.current.media)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(children: [
          LabeledPref(
            child: PrefSwitch(
              pref: optionMediaDisableAutoload,
              title: Text(L10n.of(context).load_media_manually),
              subtitle: Text(L10n.of(context).load_media_manually_description),
            ),
          ),
          PrefDropdown(
              fullWidth: false,
              title: Text(L10n.of(context).image_quality),
              subtitle: Text(L10n.of(context).save_bandwidth_using_smaller_images),
              pref: optionImageQuality,
              items: qualityItems()),
          PrefDropdown(
              fullWidth: false,
              title: Text(L10n.of(context).video_quality),
              subtitle: Text(L10n.of(context).video_quality_description),
              pref: optionMediaVideoQuality,
              items: qualityItems()),
          PrefDropdown(
              fullWidth: false,
              title: Text(L10n.of(context).media_grid_columns),
              subtitle: Text(L10n.of(context).media_grid_columns_description),
              pref: optionMediaGridColumns,
              items: [
                for (var count in [1, 2, 3, 4, 5])
                  DropdownMenuItem(
                    value: count,
                    child: Text('$count'),
                  ),
              ]),
          LabeledPref(
            child: PrefSwitch(
              pref: optionMediaDefaultMute,
              title: Text(L10n.of(context).mute_videos),
              subtitle: Text(L10n.of(context).mute_video_description),
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              pref: optionMediaDefaultLoop,
              title: Text(L10n.of(context).loop_videos),
              subtitle: Text(L10n.of(context).loop_videos_description),
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              pref: optionMediaDefaultAutoPlay,
              title: Text(L10n.of(context).autoplay_videos),
              subtitle: Text(L10n.of(context).autoplay_videos_description),
            ),
          ),
          PrefDropdown(
              fullWidth: false,
              title: Text(L10n.of(context).video_prefetch),
              subtitle: Text(L10n.of(context).video_prefetch_description),
              pref: optionMediaVideoPrefetchSeconds,
              items: [
                DropdownMenuItem(
                  value: 0,
                  child: Text(L10n.of(context).video_prefetch_unlimited),
                ),
                for (var seconds in [1, 5, 15, 30, 60])
                  DropdownMenuItem(
                    value: seconds,
                    child: Text(L10n.of(context).video_prefetch_seconds(seconds)),
                  ),
              ]),
          LabeledPref(
            child: PrefSwitch(
              pref: optionMediaBackgroundPlayback,
              title: Text(L10n.of(context).allow_background_play),
              subtitle: Text(L10n.of(context).allow_background_play_description),
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              pref: optionMediaAllowBackgroundPlayOtherApps,
              title: Text(L10n.of(context).allow_background_play_other_apps),
              subtitle: Text(L10n.of(context).allow_background_play_other_apps_description),
            ),
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
