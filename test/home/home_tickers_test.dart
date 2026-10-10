import 'package:flutter_localizations/flutter_localizations.dart' as flutter_l10n;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/home_screen.dart';

class _KeptAlivePage extends StatefulWidget {
  final String text;

  const _KeptAlivePage(this.text);

  @override
  State<_KeptAlivePage> createState() => _KeptAlivePageState();
}

class _KeptAlivePageState extends State<_KeptAlivePage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text(widget.text);
  }
}

Widget _app(List<NavigationPage> pages, int initialPage) => MaterialApp(
      localizationsDelegates: const [
        L10n.delegate,
        ...GlobalMaterialLocalizations.delegates,
        flutter_l10n.GlobalMaterialLocalizations.delegate,
        flutter_l10n.GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: L10n.delegate.supportedLocales,
      home: ScaffoldWithBottomNavigation(
        pages: pages,
        prefs: PrefServiceCache(defaults: {optionShowNavigationLabels: false}),
        initialPage: initialPage,
        builder: (_, _) => pages.map((p) => _KeptAlivePage('page ${p.id}')).toList(),
      ),
    );

void main() {
  testWidgets('Should enable the tickers of the current home page only', (tester) async {
    final pages = ['one', 'two', 'three']
        .map((id) => NavigationPage(id, (_) => id, const Icon(Icons.home_outlined), const Icon(Icons.home)))
        .toList();

    await tester.pumpWidget(_app(pages, 1));
    await tester.tap(find.byIcon(Icons.home_outlined).last);
    await tester.pumpAndSettle();

    bool enabledAround(String text) => TickerMode.valuesOf(tester.element(find.text(text, skipOffstage: false))).enabled;

    expect(find.text('page two', skipOffstage: false), findsOneWidget, reason: 'the page left is kept alive');
    expect(enabledAround('page three'), true, reason: 'the current page animates');
    expect(enabledAround('page two'), false, reason: 'a kept-alive off-screen page must stop its tickers');
  });

  testWidgets('Should move the enabled tickers to the page navigated to', (tester) async {
    final pages = ['one', 'two']
        .map((id) => NavigationPage(id, (_) => id, const Icon(Icons.home_outlined), const Icon(Icons.home)))
        .toList();
    await tester.pumpWidget(_app(pages, 0));

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();

    bool enabledAround(String text) => TickerMode.valuesOf(tester.element(find.text(text, skipOffstage: false))).enabled;
    expect(enabledAround('page two'), true, reason: 'the page navigated to animates');
    expect(enabledAround('page one'), false, reason: 'the page left stops its tickers');
  });
}
