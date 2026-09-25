import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/errors.dart';

import 'pump_app.dart';

const fullPageError = FullPageErrorWidget(error: 'boom', stackTrace: null, prefix: _prefix);

String _prefix(_) => 'prefix';

Future<void> pumpError(WidgetTester tester, {StackTrace? stackTrace}) => pumpInApp(
    tester, FullPageErrorWidget(error: 'boom', stackTrace: stackTrace, prefix: _prefix, onRetry: () {}));

// A 24 logical pixels high status bar, as on most phones
void fakeStatusBar(WidgetTester tester) {
  tester.view.padding = FakeViewPadding(top: 24 * tester.view.devicePixelRatio);
  addTearDown(tester.view.resetPadding);
}

void main() {
  testWidgets('Should keep the stack trace off the screen', (tester) async {
    await pumpError(tester, stackTrace: StackTrace.fromString('#0      SomeClass.someMethod (package:quax/a.dart:1:1)'));

    expect(find.textContaining('SomeClass.someMethod'), findsNothing,
        reason: 'The stack trace means nothing to users, it is only sent in bug reports');
    expect(find.text('boom'), findsOneWidget, reason: 'The technical reason should still be shown');
  });

  testWidgets('Should show the same card as inside lists when the error takes the whole page', (tester) async {
    await pumpError(tester);

    expect(find.byType(ErrorCard), findsOneWidget,
        reason: 'Every error should look the same, whether it takes the page or sits in a list');
    expect(tester.getTopLeft(find.byType(ErrorCard)).dy, 0,
        reason: 'The card should sit at the top like the content it replaces, not be centered');
  });

  testWidgets('Should make reporting the primary action and retrying the secondary one', (tester) async {
    await pumpError(tester);

    expect(find.widgetWithText(FilledButton, 'Report'), findsOneWidget,
        reason: 'Reporting the bug is the action we want users to take first');
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget,
        reason: 'Retrying stays available but should look secondary');
    expect(tester.getCenter(find.text('Report')).dx, greaterThan(tester.getCenter(find.text('Retry')).dx),
        reason: 'Following Material guidelines, the primary action should come last, on the right');
  });

  testWidgets('Should stay below the status bar when the error replaces a whole screen', (tester) async {
    fakeStatusBar(tester);
    await pumpInApp(tester, fullPageError);

    expect(tester.getTopLeft(find.byType(ErrorCard)).dy, greaterThanOrEqualTo(24),
        reason: 'Screens without an app bar, such as a profile, would otherwise hide the card under the status bar');
  });

  testWidgets('Should add no gap below an app bar that already avoids the status bar', (tester) async {
    fakeStatusBar(tester);
    await pumpInApp(
        tester,
        NestedScrollView(
          headerSliverBuilder: (_, _) => [const SliverAppBar(pinned: true)],
          body: fullPageError,
        ));

    final appBarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
    expect(tester.getTopLeft(find.byType(ErrorCard)).dy, appBarBottom,
        reason: 'Profile tabs sit below a collapsing app bar, which leaves the status bar padding to its body');
  });
}
