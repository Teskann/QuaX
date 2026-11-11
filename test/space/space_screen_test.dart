import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/space/space_model.dart';
import 'package:quax/space/space_player.dart';
import 'package:quax/space/space_screen.dart';
import 'package:quax/ui/errors.dart';

import '../fixtures.dart';
import '../pump_route.dart';
import '../ui/fake_images.dart';
import 'recorded_spaces.dart';

Future<void> _openSpace(WidgetTester tester, Fixture recorded) => pumpRoute(
  tester,
  const SpaceScreen(),
  RouteSettings(name: routeSpace, arguments: SpaceScreenArguments(spaceOf(recorded).id)),
);

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());
  tearDown(SpaceModel.forgetKnownSpaces);
  tearDown(SpaceDownloadModel.forgetDownloads);

  group('SpaceScreen', () {
    testWidgets('Should show the title and the hosts, without a player when nothing can be played', (tester) async {
      final space = spaceOf(recordedSpace(hasNoRecording));
      await pumpRoute(
        tester,
        const SpaceScreen(),
        RouteSettings(name: routeSpace, arguments: SpaceScreenArguments(space.id)),
      );

      expect(find.byType(ErrorCard), findsNothing, reason: 'The recorded space should load without error');
      expect(find.text(space.title), findsOneWidget, reason: 'The page shows the title of the space');
      expect(find.text('@${space.hosts.first.screenName}'), findsOneWidget, reason: 'The page lists the hosts');
      expect(find.byType(SpacePlayer), findsNothing, reason: 'There is no recording to play');
      expect(find.byIcon(Icons.download), findsNothing, reason: 'There is no recording to download');
    });

    testWidgets('Should offer to download a recorded space', (tester) async {
      await _openSpace(tester, recordedSpace(hasPlayableRecording));

      expect(find.byIcon(Icons.download), findsOneWidget, reason: 'The recording of an ended space can be saved');
    });

    testWidgets('Should show the download going on, once the space was refreshed', (tester) async {
      final recorded = recordedSpace(hasPlayableRecording);
      // The temporary folder never comes. So the download keeps running.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (_) => Completer<Object?>().future,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        ),
      );
      await _openSpace(tester, recorded);
      // Open it again. The known space shows at once, then refreshes.
      await _openSpace(tester, recorded);

      await tester.tap(find.byIcon(Icons.download));
      await tester.pump();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
        reason: 'Without the ring, the user taps again',
      );
    });

    testWidgets('Should not offer to download a live space', (tester) async {
      await _openSpace(tester, recordedSpace(isLive));

      expect(find.byIcon(Icons.download), findsNothing, reason: 'A live space has no recording yet');
    });
  });
}
