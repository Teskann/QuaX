import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';
import 'package:quax/utils/iterables.dart';

/// The theme colors offered to the user
Iterable<MapEntry<String, Color>> get selectableThemeColors =>
    themeColors.entries.getRange(0, themeColors.values.length - 1);

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
          PrefSwitch(
            title: Text(L10n.of(context).x_design),
            subtitle: Text(L10n.of(context).x_design_description),
            pref: optionXStyle,
          ),
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
            const DropdownMenuItem(value: 'accent', child: Text('Accent')),
            ...selectableThemeColors.map(
                (scheme) => DropdownMenuItem(value: scheme.key, child: Text(toBeginningOfSentenceCase(scheme.key)!)))
          ]),
          const TrueBlackPref(),
          PrefSwitch(
            title: Text(L10n.of(context).true_black_tweet_cards),
            pref: optionThemeTrueBlackTweetCards,
            disabled: !prefs.get(optionThemeTrueBlack),
            subtitle: Text(
              L10n.of(context).use_true_black_for_tweet_cards,
            ),
          ),
          PrefSwitch(
            title: Text(L10n.of(context).show_navigation_labels),
            pref: optionShowNavigationLabels,
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

    return PrefSwitch(
      title: Text(L10n.of(context).true_black),
      pref: optionThemeTrueBlack,
      subtitle: Text(
        L10n.of(context).use_true_black_for_the_dark_mode_theme,
      ),
      onChange: (bool changeValue) {
        prefs.set(optionThemeTrueBlackTweetCards, changeValue);
      },
    );
  }
}
