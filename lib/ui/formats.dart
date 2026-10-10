import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

final Map<String, NumberFormat> _compactNumberFormats = {};

final RegExp _localeSeparator = RegExp(r'[-_]');

final Map<String, Locale> _parsedLocales = {};

/// The compact number format of the current locale, built once per locale instead of once per tweet
NumberFormat compactNumberFormat() =>
    _compactNumberFormats.putIfAbsent(Intl.getCurrentLocale(), () => NumberFormat.compact());

/// Parses a locale name like `en_US` or `pt-BR`, remembering the result
Locale parseLocale(String name) => _parsedLocales.putIfAbsent(name, () {
      final parts = name.split(_localeSeparator);
      return parts.length == 1 ? Locale(parts[0]) : Locale(parts[0], parts[1]);
    });

/// The width in pixels an image laid out within [constraints] needs to be decoded at, or null when it is unknown
int? decodeWidthFor(BoxConstraints constraints, double devicePixelRatio) {
  if (!constraints.hasBoundedWidth) return null;
  final width = (constraints.maxWidth * devicePixelRatio).round();
  return width > 0 ? width : null;
}
