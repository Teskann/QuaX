import 'dart:math';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/onboarding/_page.dart';
import 'package:quax/settings/_theme.dart';

/// Picks the theme mode, the color and true black, applied to the whole app as soon as they are picked.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  Widget _mode(BuildContext context, BasePrefService prefs) {
    final l10n = L10n.of(context);
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: 'system', icon: const Icon(Icons.brightness_auto), label: Text(l10n.system)),
        ButtonSegment(value: 'light', icon: const Icon(Icons.light_mode), label: Text(l10n.light)),
        ButtonSegment(value: 'dark', icon: const Icon(Icons.dark_mode), label: Text(l10n.dark)),
      ],
      selected: {prefs.get<String>(optionThemeMode) ?? 'system'},
      onSelectionChanged: (selected) => prefs.set(optionThemeMode, selected.first),
    );
  }

  Widget _colors(BasePrefService prefs) {
    final current = prefs.get<String>(optionThemeColor) ?? 'accent';
    void pick(String color) => prefs.set(optionThemeColor, color);
    final swatches = [
      _SystemSwatch(selected: current == 'accent', onTap: () => pick('accent')),
      ...selectableThemeColors.map((e) => _Swatch(
          color: e.value, label: themeColorName(e.key), selected: current == e.key, onTap: () => pick(e.key))),
    ];
    // All the colors on one row, as large as the width allows
    return LayoutBuilder(builder: (context, constraints) {
      const spacing = 8.0;
      final size = min(48.0, (constraints.maxWidth - spacing * (swatches.length - 1)) / swatches.length);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: swatches.map((swatch) => SizedBox.square(dimension: size, child: swatch)).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context);
    final label = Theme.of(context).textTheme.titleSmall;
    final gap = OnboardingPage.isShort(context) ? 8.0 : 12.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(L10n.of(context).theme_mode, style: label),
        SizedBox(height: gap),
        _mode(context, prefs),
        SizedBox(height: gap * 2),
        Text(L10n.of(context).theme, style: label),
        SizedBox(height: gap),
        _colors(prefs),
        // True black only applies to the dark mode
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: prefs.get<String>(optionThemeMode) == 'light'
              ? const SizedBox(width: double.infinity)
              : const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: ListTileTheme(contentPadding: EdgeInsets.zero, child: TrueBlackPref()),
                ),
        ),
      ],
    );
  }
}

/// The color of the device's wallpaper, which the app follows by default.
class _SystemSwatch extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _SystemSwatch({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DynamicColorBuilder(
      builder: (light, darkScheme) => _Swatch(
        color: (dark ? darkScheme : light)?.primary,
        label: themeColorName('accent'),
        icon: Icons.wallpaper,
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

/// A color to pick, with an [icon] telling what it is, if any. Without a [color], it is drawn as a neutral one.
class _Swatch extends StatelessWidget {
  final Color? color;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  const _Swatch({this.color, required this.label, this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fill = color ?? colors.surfaceContainerHighest;
    final onFill = color == null
        ? colors.onSurfaceVariant
        : (ThemeData.estimateBrightnessForColor(fill) == Brightness.dark ? Colors.white : Colors.black);
    final symbol = selected ? Icons.check : icon;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? colors.primary : Colors.transparent, width: 3),
          ),
          child: symbol == null ? null : Icon(symbol, color: onFill),
        ),
      ),
    );
  }
}
