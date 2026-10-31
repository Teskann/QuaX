import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/space/space_model.dart';
import 'package:quax/space/space_player.dart';
import 'package:quax/space/space_screen.dart';
import 'package:quax/ui/errors.dart';

import '../community/pump_community.dart';
import '../ui/fake_images.dart';
import 'recorded_spaces.dart';

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());
  tearDown(SpaceModel.forgetKnownSpaces);

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
    });
  });
}
