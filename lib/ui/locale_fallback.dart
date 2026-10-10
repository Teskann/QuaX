import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';

const _fallbackLocale = Locale('en');

bool _hasFormats(String locale) => NumberFormat.localeExists(locale) && DateFormat.localeExists(locale);

/// The locale to build a [NumberFormat] or a [DateFormat] with: [locale] (the current one by default) when intl has
/// its number and date data, else its language, else English. QuaX can be translated in languages (Esperanto)
/// that Flutter and intl know nothing about, and formatting with them throws.
String safeIntlLocale([String? locale]) {
  final name = Intl.canonicalizedLocale(locale ?? Intl.getCurrentLocale());
  return [name, Intl.shortLocale(name)].firstWhere(_hasFormats, orElse: () => _fallbackLocale.languageCode);
}

/// Loads the English texts of [_base] when it has none for the locale of the app, so that the Material, Cupertino and
/// widgets localizations never come out empty.
class EnglishFallbackDelegate extends LocalizationsDelegate<dynamic> {
  final LocalizationsDelegate<dynamic> _base;

  const EnglishFallbackDelegate(this._base);

  @override
  Type get type => _base.type;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<dynamic> load(Locale locale) => _base.load(_base.isSupported(locale) ? locale : _fallbackLocale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<dynamic> old) =>
      old is! EnglishFallbackDelegate || _base.shouldReload(old._base);
}

final List<LocalizationsDelegate<dynamic>> appLocalizationsDelegates = [
  L10n.delegate,
  ...<LocalizationsDelegate<dynamic>>[
    ...GlobalMaterialLocalizations.delegates,
    flutter_l10n.GlobalMaterialLocalizations.delegate,
    flutter_l10n.GlobalCupertinoLocalizations.delegate,
  ].map(EnglishFallbackDelegate.new),
];
