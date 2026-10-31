import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/space/space.dart';
import 'package:quax/space/space_status.dart';

import '../ui/pump_app.dart';
import 'recorded_spaces.dart';

Future<String> _statusOf(WidgetTester tester, Space space) async {
  await pumpInApp(tester, SpaceStatusLine(space: space));
  return tester.widget<Text>(find.byType(Text)).data!;
}

void main() {
  testWidgets('Should say how many listen to a live space right now', (tester) async {
    final space = spaceOf(recordedSpace((space) => isLive(space) && space.listeningCount > 1));

    expect(
      await _statusOf(tester, space),
      'Live · ${space.listeningCount} listening',
      reason: 'X counts everyone who ever tuned in apart: that would overstate who listens now',
    );
  });

  testWidgets('Should say how many tuned in to an ended space, and how long it lasted', (tester) async {
    final space = spaceOf(recordedSpace((space) => space.state == SpaceState.ended && space.duration != null));

    expect(
      await _statusOf(tester, space),
      'Ended · ${space.tunedInCount} tuned in · ${formatSpaceDuration(space.duration!)}',
      reason: 'Once over, everyone who listened counts',
    );
  });
}
