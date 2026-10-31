import 'package:quax/space/space.dart';

import '../fixtures.dart';

/// The first recorded AudioSpaceById answer whose space matches [where]. What X answers changes with every capture,
/// so a test picks a space by what it shows, never by its file.
Fixture recordedSpace(bool Function(Space space) where) => fixturesOf('AudioSpaceById').firstWhere((recorded) {
  final space = Space.fromGraphql(recorded.body);
  return space != null && where(space);
}, orElse: () => throw StateError('No recorded space fits this test: capture posts sharing such a space again'));

Space spaceOf(Fixture recorded) => Space.fromGraphql(recorded.body)!;

bool isLive(Space space) => space.state == SpaceState.live;

bool hasPlayableRecording(Space space) => space.state == SpaceState.ended && space.canPlay;

bool hasNoRecording(Space space) => space.state == SpaceState.ended && !space.hasRecording;

bool isScheduled(Space space) => space.state == SpaceState.scheduled;
