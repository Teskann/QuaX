import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/x_overlay_feed.dart';

import '../ui/pump_app.dart';

void main() {
  const statusBar = 24.0;
  const headerHeight = 96.0;

  Future<void> pumpFailedGroup(WidgetTester tester, {required bool overlay}) async {
    final model = GroupModel('g1')..setError(Exception('boom'));
    const content = SubscriptionGroupScreenContent(id: 'g1');
    tester.view
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: statusBar)
      ..viewPadding = const FakeViewPadding(top: statusBar);
    addTearDown(tester.view.reset);
    await pumpInApp(
        tester,
        Provider<GroupModel>.value(
            value: model,
            child: overlay
                ? XOverlayFeed(
                    headerHeight: headerHeight,
                    scrollController: ScrollController(),
                    header: const SizedBox(height: headerHeight),
                    body: content)
                : content));
  }

  group('SubscriptionGroupScreenContent load error', () {
    testWidgets('Should start below the header laid over the feed', (tester) async {
      await pumpFailedGroup(tester, overlay: true);

      expect(find.byType(ErrorCard), findsOneWidget, reason: 'The failure of the group should be reported');
      expect(tester.getTopLeft(find.byType(ErrorCard)).dy, greaterThanOrEqualTo(statusBar + headerHeight),
          reason: 'The error card must not be under the overlay header');
      expect(find.byType(AppBar), findsNothing, reason: 'The header is already there, the error brings no app bar');
    });

    testWidgets('Should be centered in the room below the header, which is counted once', (tester) async {
      await pumpFailedGroup(tester, overlay: true);

      const inset = statusBar + headerHeight;
      final room = tester.getSize(find.byType(XOverlayFeed)).height - inset;
      expect(tester.getCenter(find.byType(ErrorCard)).dy, moreOrLessEquals(inset + room / 2, epsilon: 2),
          reason: 'The header inset is counted once, not once by the padding and once by the safe area');
    });

    testWidgets('Should keep its own app bar when no header is laid over the feed', (tester) async {
      await pumpFailedGroup(tester, overlay: false);

      expect(find.byType(ScaffoldErrorWidget), findsOneWidget, reason: 'A pushed group screen has no overlay header');
      expect(find.byType(AppBar), findsOneWidget, reason: 'The regular design keeps its app bar on the error');
    });
  });
}
