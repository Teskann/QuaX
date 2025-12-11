import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';

class SettingsAccessibilityFragment extends StatelessWidget {
  const SettingsAccessibilityFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.current.accessibility)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(children: [
          PrefSlider(
            title: Text(L10n.of(context).text_scale_factor),
            pref: optionTextScaleFactor,
            subtitle: Text(L10n.of(context).text_scale_factor_description),
            min: 1.0,
            max: 1.5,
            divisions: 10,
          ),
          PrefSwitch(
            title: Text(L10n.of(context).disable_animations),
            pref: optionDisableAnimations,
            subtitle: Text(
              L10n.of(context).disable_animations_description,
            ),
          )
        ]),
      ),
    );
  }
}
