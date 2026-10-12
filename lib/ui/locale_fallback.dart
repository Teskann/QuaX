import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';

const _english = Locale('en');

/// Loads [delegate] in English for the locales it has no data for, such as Esperanto.
class _EnglishFallbackDelegate extends LocalizationsDelegate<dynamic> {
  final LocalizationsDelegate<dynamic> delegate;

  const _EnglishFallbackDelegate(this.delegate);

  @override
  Type get type => delegate.type;

  @override
  bool isSupported(Locale locale) => !delegate.isSupported(locale);

  @override
  Future<dynamic> load(Locale locale) => delegate.load(_english);

  @override
  bool shouldReload(_EnglishFallbackDelegate old) => false;
}

const _flutterDelegates = <LocalizationsDelegate<dynamic>>[
  ...GlobalMaterialLocalizations.delegates,
  flutter_l10n.GlobalMaterialLocalizations.delegate,
  flutter_l10n.GlobalCupertinoLocalizations.delegate,
];

final appLocalizationsDelegates = <LocalizationsDelegate<dynamic>>[
  L10n.delegate,
  ..._flutterDelegates,
  ..._flutterDelegates.map(_EnglishFallbackDelegate.new),
];

/// The app's locale when intl can format numbers and dates in it, English otherwise.
String formattingLocale() => Intl.verifiedLocale(
  Intl.getCurrentLocale(),
  (locale) => NumberFormat.localeExists(locale) && DateFormat.localeExists(locale),
  onFailure: (_) => _english.languageCode,
)!;
