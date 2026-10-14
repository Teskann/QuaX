import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/group/unrelated_tweets_warning.dart';
import 'package:quax/ui/errors.dart';

import '../ui/pump_app.dart';

void main() {
  testWidgets('Should warn with an amber icon, and make switching accounts the primary action', (tester) async {
    await pumpInApp(tester, const UnrelatedTweetsWarning());

    final context = tester.element(find.byType(UnrelatedTweetsWarning));
    final amber = Colors.amber.harmonizeWith(Theme.of(context).colorScheme.primary);
    expect(tester.widget<StatusCard>(find.byType(StatusCard)).level, StatusLevel.warning,
        reason: 'Posts from strangers are a problem of X, not an error of the feed');
    expect(tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color, amber,
        reason: 'A warning should not look as alarming as the red icon of errors');
    expect(find.text('Feed issue detected'), findsOneWidget, reason: 'The title should say what is wrong');
    expect(find.widgetWithText(FilledButton, 'Account settings'), findsOneWidget,
        reason: 'Switching to another account is what fixes the feed, so it is the primary action');
    expect(find.widgetWithText(TextButton, 'More info'), findsOneWidget,
        reason: 'Why X does this should stay one tap away');
  });
}
