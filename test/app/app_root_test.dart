import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/main.dart';

class _CountingPrefs extends PrefServiceCache {
  int added = 0;
  int removed = 0;

  _CountingPrefs()
      : super(defaults: {
          optionShouldCheckForUpdates: false,
          optionLocale: 'en',
          optionThemeTrueBlack: false,
          optionThemeMode: 'system',
          optionThemeColor: 'blue',
          optionDisableScreenshots: false,
          optionTextScaleFactor: 1.0,
          optionDisableAnimations: false,
        });

  @override
  void addKeyListener(String key, VoidCallback f) {
    added++;
    super.addKeyListener(key, f);
  }

  @override
  void removeKeyListener(String key, VoidCallback f) {
    removed++;
    super.removeKeyListener(key, f);
  }
}

/// The app root swaps ErrorWidget.builder, which the test framework wants back as it was
void _testApp(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      await body(tester);
    } finally {
      ErrorWidget.builder = errorWidgetBuilder;
    }
  });
}

Future<void> _pumpApp(WidgetTester tester, BasePrefService prefs, {VoidCallback? onBuild}) {
  return tester.pumpWidget(PrefService(
    service: prefs,
    child: FritterApp(
      onboarding: true,
      homeBuilder: (_) => const Scaffold(body: Text('home')),
      onBuild: onBuild,
    ),
  ));
}

void main() {
  group('FritterApp', () {
    _testApp('Should register the preference listeners once, however many times the dependencies change', (tester) async {
      final prefs = _CountingPrefs();
      addTearDown(tester.view.reset);
      await _pumpApp(tester, prefs);
      final registered = prefs.added;

      tester.view.physicalSize = const Size(800, 1200);
      await tester.pump();
      tester.view.physicalSize = const Size(600, 900);
      await tester.pump();
      await prefs.set(optionThemeColor, 'red');
      await tester.pump();
      await prefs.set(optionLocale, 'fr');
      await tester.pump();

      expect(registered, 8, reason: 'the root watches 8 preferences');
      expect(prefs.added, registered, reason: 'dependency changes must not register listeners again');
    });

    _testApp('Should remove every preference listener when disposed', (tester) async {
      final prefs = _CountingPrefs();
      await _pumpApp(tester, prefs);

      await tester.pumpWidget(const SizedBox());

      expect(prefs.removed, prefs.added, reason: 'each listener registered must be removed');
    });

    _testApp('Should rebuild the root once when a watched preference changes', (tester) async {
      final prefs = _CountingPrefs();
      var builds = 0;
      addTearDown(tester.view.reset);
      await _pumpApp(tester, prefs, onBuild: () => builds++);
      tester.view.physicalSize = const Size(800, 1200);
      await tester.pump();
      tester.view.physicalSize = const Size(600, 900);
      await tester.pump();
      final before = builds;

      await prefs.set(optionThemeColor, 'red');
      await tester.pump();

      expect(builds - before, 1, reason: 'one preference change must cause one rebuild');
    });

    _testApp('Should not rebuild the root when only the MediaQuery changes', (tester) async {
      final prefs = _CountingPrefs();
      var builds = 0;
      addTearDown(tester.view.reset);
      await _pumpApp(tester, prefs, onBuild: () => builds++);
      final before = builds;

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pump();
      tester.view.viewInsets = FakeViewPadding.zero;
      tester.view.physicalSize = const Size(600, 900);
      await tester.pump();

      expect(builds, before, reason: 'keyboard animation frames must not rebuild the app root');
    });

    _testApp('Should scale the text with the preference', (tester) async {
      final prefs = _CountingPrefs();
      await prefs.set(optionTextScaleFactor, 2.0);
      await _pumpApp(tester, prefs);

      final scale = MediaQuery.textScalerOf(tester.element(find.text('home'))).scale(10);

      expect(scale, 20, reason: 'the text scale preference applies to the routes');
    });
  });

  group('AppThemeCache', () {
    AppThemes resolve(AppThemeCache cache, {String color = 'blue', bool trueBlack = false}) => cache.resolve(
          themeColor: color,
          trueBlack: trueBlack,
          disableAnimations: false,
          lightDynamic: null,
          darkDynamic: null,
        );

    test('Should return the same themes for the same inputs', () {
      final cache = AppThemeCache();

      expect(identical(resolve(cache), resolve(cache)), true, reason: 'unchanged inputs must hit the cache');
    });

    test('Should build new themes when an input changes', () {
      final cache = AppThemeCache();
      final first = resolve(cache);

      expect(identical(first, resolve(cache, color: 'red')), false, reason: 'a new color must rebuild the themes');
      expect(identical(first, resolve(cache, trueBlack: true)), false, reason: 'true black must rebuild the themes');
    });
  });

  group('defaultLogLevel', () {
    test('Should only log warnings in release builds', () {
      expect(defaultLogLevel(release: true), Level.WARNING, reason: 'release builds skip the info logs');
    });

    test('Should keep logging info in debug builds', () {
      expect(defaultLogLevel(release: false), Level.INFO, reason: 'debug builds keep the current level');
    });
  });
}
