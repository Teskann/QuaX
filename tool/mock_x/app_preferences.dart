/// The preferences QuaX starts with on the emulator: past the onboarding, which ignores incoming
/// links, and without the launch dialogs that would cover the screens.
const emulatorPreferences = {
  'onboarding.done': true,
  'discord_popup.dismissed': true,
  'should_check_for_updates': false,
};

/// The shared_prefs/FlutterSharedPreferences.xml that the pref package (prefix 'pref_') reads [booleans] from.
String sharedPreferencesXml(Map<String, bool> booleans) => [
      "<?xml version='1.0' encoding='utf-8' standalone='yes' ?>",
      '<map>',
      ...booleans.entries.map((e) => '    <boolean name="flutter.pref_${e.key}" value="${e.value}" />'),
      '</map>',
      '',
    ].join('\n');
