import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// Pumps [body] in a localized app with the preferences the widgets read, overridden by [prefs].
/// Without [settle], only a few frames are drawn: enough to build the content
/// while images, which never finish loading in tests, keep spinning.
/// [aboveApp] wraps the whole app, for what overlays such as drag proxies must read.
Future<void> pumpInApp(WidgetTester tester, Widget body,
    {bool settle = true, Map<String, dynamic> prefs = const {}, Widget Function(Widget app)? aboveApp}) async {
  // Videos wait for their visibility to be reported, which is otherwise
  // debounced by a timer left pending when the test ends.
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  await tester.pumpWidget(PrefService(
    service: PrefServiceCache(defaults: {
      optionThemeTrueBlack: false,
      optionThemeTrueBlackTweetCards: false,
      optionLocale: 'en',
      optionNonConfirmationBiasMode: false,
      alwaysShowFullTweetContents: false,
      optionUseAbsoluteTimestamp: false,
      optionImageQuality: 'medium',
      optionMediaVideoQuality: 'medium',
      optionMediaDisableAutoload: false,
      optionMediaDefaultMute: true,
      optionMediaDefaultLoop: false,
      optionMediaDefaultAutoPlay: false,
      optionMediaBackgroundPlayback: true,
      optionTweetsHideSensitive: true,
      optionDefaultProfileTab: 'posts',
      ...prefs,
    }),
    child: (aboveApp ?? (app) => app)(MaterialApp(
      localizationsDelegates: const [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
        flutter_l10n.GlobalMaterialLocalizations.delegate,
        flutter_l10n.GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.delegate.supportedLocales,
      home: Scaffold(body: body),
    )),
  ));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}
