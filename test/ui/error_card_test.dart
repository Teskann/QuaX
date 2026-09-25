import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/errors.dart';

import 'pump_app.dart';

Future<void> pumpCard(WidgetTester tester, Object error) =>
    pumpInApp(tester, ErrorCard(error: error, stackTrace: null, prefix: (_) => 'Unable to load', onRetry: () {}));

void main() {
  testWidgets('Should offer to report an unexpected error, and to retry', (tester) async {
    await pumpCard(tester, StateError('boom'));

    expect(find.text('Unable to load'), findsOneWidget, reason: 'The title should say what failed');
    expect(find.text('Bad state: boom'), findsOneWidget, reason: 'The technical reason should be shown below');
    expect(find.widgetWithText(FilledButton, 'Report'), findsOneWidget,
        reason: 'An unexpected error is a bug, so reporting it is the primary action');
    expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget, reason: 'Retrying should stay available');
  });

  testWidgets('Should offer to add an account rather than to report a rate limit', (tester) async {
    await pumpCard(tester, RateLimitedException());

    expect(find.widgetWithText(FilledButton, 'Add account'), findsOneWidget,
        reason: 'Another account is what gets the user past a rate limit');
    expect(find.text('Report'), findsNothing, reason: 'A rate limit is not a bug, reports would only be noise');
    expect(find.text('Unable to load'), findsNothing,
        reason: 'The rate limit title explains the problem better than the generic message');
  });

  testWidgets('Should look like a tweet, with a bright red icon', (tester) async {
    await pumpCard(tester, StateError('boom'));

    final context = tester.element(find.byType(ErrorCard));
    final colors = Theme.of(context).colorScheme;
    final red = Colors.red.harmonizeWith(colors.primary);
    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, red,
        reason: 'The icon should use a red brighter than the error color of the theme');
    expect(tester.widget<Card>(find.byType(Card)).color, tweetCardColor(context),
        reason: 'The card sits among tweets, so it should share their background, true black mode included');
  });
}
