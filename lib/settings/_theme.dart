import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';
import 'package:quax/utils/iterables.dart';
import 'package:quax/ui/labeled_pref.dart';

/// The theme colors offered to the user
Iterable<MapEntry<String, Color>> get selectableThemeColors =>
    themeColors.entries.getRange(0, themeColors.values.length - 1);

String themeColorName(String key) => key == 'accent' ? 'Accent' : toBeginningOfSentenceCase(key)!;

class SettingsThemeFragment extends StatelessWidget {
  const SettingsThemeFragment({super.key});

  @override
  Widget build(BuildContext context) {
    final BasePrefService prefs = PrefService.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(L10n.current.theme)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(children: [
          PrefDropdown(fullWidth: false, title: Text(L10n.of(context).theme_mode), pref: optionThemeMode, items: [
            DropdownMenuItem(
              value: 'system',
              child: Text(L10n.of(context).system),
            ),
            DropdownMenuItem(
              value: 'light',
              child: Text(L10n.of(context).light),
            ),
            DropdownMenuItem(
              value: 'dark',
              child: Text(L10n.of(context).dark),
            ),
          ]),
          PrefDropdown(title: Text(L10n.of(context).theme), fullWidth: false, pref: optionThemeColor, items: [
            DropdownMenuItem(value: 'accent', child: Text(themeColorName('accent'))),
            ...selectableThemeColors.map(
                (scheme) => DropdownMenuItem(value: scheme.key, child: Text(themeColorName(scheme.key))))
          ]),
          const TrueBlackPref(),
          LabeledPref(
            child: PrefSwitch(
              title: Text(L10n.of(context).true_black_tweet_cards),
              pref: optionThemeTrueBlackTweetCards,
              disabled: !prefs.get(optionThemeTrueBlack),
              subtitle: Text(
                L10n.of(context).use_true_black_for_tweet_cards,
              ),
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              title: Text(L10n.of(context).show_navigation_labels),
              pref: optionShowNavigationLabels,
            ),
          ),
        ]),
      ),
    );
  }
}

class TrueBlackPref extends StatelessWidget {
  const TrueBlackPref({super.key});

  @override
  Widget build(BuildContext context) {
    final BasePrefService prefs = PrefService.of(context);

    return LabeledPref(
      child: PrefSwitch(
        title: Text(L10n.of(context).true_black),
        pref: optionThemeTrueBlack,
        subtitle: Text(
          L10n.of(context).use_true_black_for_the_dark_mode_theme,
        ),
        onChange: (bool changeValue) {
          prefs.set(optionThemeTrueBlackTweetCards, changeValue);
        },
      ),
    );
  }
}
