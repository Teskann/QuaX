import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';

/// Pumps [body] in a localized app with the preferences the widgets read
Future<void> pumpInApp(WidgetTester tester, Widget body) async {
  await tester.pumpWidget(PrefService(
    service: PrefServiceCache(defaults: {optionThemeTrueBlack: false, optionThemeTrueBlackTweetCards: false}),
    child: MaterialApp(
      localizationsDelegates: const [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
        flutter_l10n.GlobalMaterialLocalizations.delegate,
        flutter_l10n.GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.delegate.supportedLocales,
      home: Scaffold(body: body),
    ),
  ));
  await tester.pumpAndSettle();
}
