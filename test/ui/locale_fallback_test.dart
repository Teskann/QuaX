import 'package:flutter/cupertino.dart' show CupertinoLocalizations;
import 'package:flutter/material.dart' as legacy show MaterialLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/locale_fallback.dart';

Future<void> _pumpWithLocale(WidgetTester tester, Locale locale, Widget body) async {
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: appLocalizationsDelegates,
    supportedLocales: L10n.delegate.supportedLocales,
    locale: locale,
    home: Scaffold(body: body),
  ));
  await tester.pumpAndSettle();
}

Future<BuildContext> _pumpForContext(WidgetTester tester, Locale locale) async {
  await _pumpWithLocale(tester, locale, const SizedBox());
  return tester.element(find.byType(Scaffold));
}

void main() {
  setUpAll(() => initializeDateFormatting());

  tearDown(() => Intl.defaultLocale = null);

  group('Safe intl locale', () {
    test('Should keep a locale that intl knows', () {
      expect(safeIntlLocale('pt_BR'), 'pt_BR', reason: 'A supported locale should be used as it is');
    });

    test('Should write a locale the way intl does', () {
      expect(safeIntlLocale('pt-BR'), 'pt_BR', reason: 'The dash of a language tag should be understood');
    });

    test('Should use English for Esperanto, which intl has no data for', () {
      expect(safeIntlLocale('eo'), 'en', reason: 'Esperanto should fall back on English');
    });

    test('Should use English for a locale that does not exist', () {
      expect(safeIntlLocale('xx'), 'en', reason: 'An unknown locale should fall back on English');
    });

    test('Should use the language of a region that intl does not know', () {
      expect(safeIntlLocale('fr_XX'), 'fr', reason: 'The language alone should be kept when its region is unknown');
    });

    test('Should use the current locale when none is given', () {
      Intl.defaultLocale = 'de';

      expect(safeIntlLocale(), 'de', reason: 'The locale of the app should be used by default');
    });

    test('Should use English when the current locale is Esperanto', () {
      Intl.defaultLocale = 'eo';

      expect(safeIntlLocale(), 'en', reason: 'The locale of the app should not break the formats when it is Esperanto');
    });

    test('Should build formats that do not throw with Esperanto', () {
      Intl.defaultLocale = 'eo';

      expect(NumberFormat.compact(locale: safeIntlLocale()).format(1500), '1.5K',
          reason: 'Numbers should be formatted in the fallback locale');
      expect(DateFormat('yyyy-MM-dd', safeIntlLocale()).format(DateTime(2026, 1, 2)), '2026-01-02',
          reason: 'Dates should be formatted in the fallback locale');
    });
  });

  group('English fallback delegate', () {
    const base = flutter_l10n.GlobalMaterialLocalizations.delegate;
    const delegate = EnglishFallbackDelegate(base);

    test('Should support every locale', () {
      expect(base.isSupported(const Locale('eo')), isFalse, reason: 'Flutter has no Material texts in Esperanto');
      expect(delegate.isSupported(const Locale('eo')), isTrue, reason: 'The fallback should accept Esperanto');
    });

    test('Should provide the type of the delegate it wraps', () {
      expect(delegate.type, base.type, reason: 'Widgets look the localizations up by their type');
    });

    test('Should load the locale itself when the wrapped delegate supports it', () async {
      final loaded = await delegate.load(const Locale('de')) as flutter_l10n.GlobalMaterialLocalizations;

      expect(loaded.backButtonTooltip, 'Zurück', reason: 'A supported locale should not be replaced by English');
    });

    test('Should load English when the wrapped delegate does not support the locale', () async {
      final loaded = await delegate.load(const Locale('eo')) as flutter_l10n.GlobalMaterialLocalizations;

      expect(loaded.backButtonTooltip, 'Back', reason: 'Esperanto should get the English texts');
    });

    test('Should reload when the delegate before it was not a fallback', () {
      expect(delegate.shouldReload(base), isTrue, reason: 'A different kind of delegate means something changed');
    });

    test('Should follow the wrapped delegate to decide whether to reload', () {
      expect(delegate.shouldReload(const EnglishFallbackDelegate(base)), base.shouldReload(base),
          reason: 'The fallback should reload when its wrapped delegate would');
    });
  });

  group('App with an unsupported language', () {
    testWidgets('Should read the texts of the app in Esperanto', (tester) async {
      await _pumpWithLocale(tester, const Locale('eo'), Builder(builder: (context) => Text(L10n.of(context).language)));

      expect(find.text('Lingvo'), findsOneWidget, reason: 'The app strings should keep their Esperanto translation');
    });

    testWidgets('Should give Material, Cupertino and widgets localizations in English', (tester) async {
      final context = await _pumpForContext(tester, const Locale('eo'));

      expect(MaterialLocalizations.of(context).backButtonTooltip, 'Back',
          reason: 'Material widgets should have their texts');
      expect(legacy.MaterialLocalizations.of(context).backButtonTooltip, 'Back',
          reason: 'Material localizations should be found');
      expect(CupertinoLocalizations.of(context).alertDialogLabel, 'Alert',
          reason: 'Cupertino widgets should have their texts');
      expect(WidgetsLocalizations.of(context).textDirection, TextDirection.ltr,
          reason: 'Widgets should have a text direction');
    });

    testWidgets('Should draw widgets that need the Material localizations', (tester) async {
      await _pumpWithLocale(
          tester,
          const Locale('eo'),
          Column(children: [
            const BackButton(),
            SizedBox(
                height: 400,
                child: CalendarDatePicker(
                    initialDate: DateTime(2026, 5, 1),
                    firstDate: DateTime(2026, 1, 1),
                    lastDate: DateTime(2026, 12, 31),
                    onDateChanged: (_) {})),
          ]));

      expect(tester.takeException(), isNull, reason: 'Esperanto should not break widgets that read the localizations');
      expect(find.byType(BackButton), findsOneWidget, reason: 'The back button should be drawn');
      expect(find.text('May 2026'), findsOneWidget, reason: 'Dates should be written in English');
    });

    testWidgets('Should format numbers and dates while the locale of the app is Esperanto', (tester) async {
      await _pumpWithLocale(
          tester,
          const Locale('eo'),
          Builder(
              builder: (context) => Text(
                  '${NumberFormat.compact(locale: safeIntlLocale()).format(2500)} '
                  '${DateFormat.yMMMd(safeIntlLocale()).format(DateTime(2026, 5, 1))}')));

      expect(Intl.defaultLocale, 'eo', reason: 'The app should be in Esperanto for this test to mean something');
      expect(find.text('2.5K May 1, 2026'), findsOneWidget, reason: 'Formats should fall back on English');
    });

    testWidgets('Should keep the localizations of a supported language', (tester) async {
      final context = await _pumpForContext(tester, const Locale('de'));

      expect(MaterialLocalizations.of(context).backButtonTooltip, 'Zurück',
          reason: 'A language Flutter knows should not be replaced by English');
    });
  });
}
