import 'package:flutter_test/flutter_test.dart';
import 'package:quax/space/space.dart';

import '../fixtures.dart';
import 'recorded_spaces.dart';

Fixture _live() => recordedSpace(isLive);
Fixture _recording() => recordedSpace(hasPlayableRecording);
Fixture _noRecording() => recordedSpace(hasNoRecording);
Fixture _scheduled() => recordedSpace(isScheduled);

Map<String, dynamic> _withMetadata(Fixture recorded, Map<String, dynamic> changes) => {
  'data': {
    'audioSpace': <String, dynamic>{
      ...recorded.body['data']['audioSpace'],
      'metadata': <String, dynamic>{...recorded.body['data']['audioSpace']['metadata'], ...changes},
    },
  },
};

void main() {
  group('Space.fromGraphql()', () {
    test('Should read every recorded space', () {
      for (final recorded in fixturesOf('AudioSpaceById')) {
        final space = Space.fromGraphql(recorded.body);

        expect(space?.id, recorded.variables['id'], reason: '$recorded: the space asked for should be read');
        expect(space!.mediaKey, isNotEmpty, reason: '$recorded: the media key is what leads to the audio');
        expect(space.hosts, isNotEmpty, reason: '$recorded: a space always has a host, shown on the card');
      }
    });

    test('Should let a live space be listened to, with its listeners and speakers', () {
      final space = spaceOf(_live());

      expect(space.canPlay, isTrue, reason: 'A live space can always be joined');
      expect(space.listeningCount, greaterThan(0), reason: 'The card shows how many are listening now');
      expect(
        space.tunedInCount,
        greaterThanOrEqualTo(space.listeningCount),
        reason: 'Everyone listening now is among those who tuned in since the start',
      );
      expect(
        space.speakers,
        everyElement(predicate<SpaceUser>((u) => u.screenName.isNotEmpty)),
        reason: 'Each speaker opens their profile, so needs a screen name',
      );
    });

    test('Should play the recording of an ended space only when X kept one', () {
      final recording = spaceOf(_recording());
      final noRecording = spaceOf(_noRecording());

      expect(recording.duration, greaterThan(Duration.zero), reason: 'The card shows how long the space lasted');
      expect(noRecording.canPlay, isFalse, reason: 'Nothing can be played when X kept no recording');
    });

    test('Should read when a scheduled space starts, and not play it', () {
      final space = spaceOf(_scheduled());

      expect(space.scheduledStart, isNotNull, reason: 'The card shows when it starts');
      expect(space.canPlay, isFalse, reason: 'There is nothing to listen to yet');
    });

    test('Should read the times X sends as strings as well as numbers', () {
      final recorded = _recording();
      final endedAt = recorded.body['data']['audioSpace']['metadata']['ended_at'];
      final asNumber = Space.fromGraphql(_withMetadata(recorded, {'ended_at': int.parse('$endedAt')}))!;

      expect(
        spaceOf(recorded).endedAt,
        asNumber.endedAt,
        reason: 'X sends ended_at as a string and started_at as a number: both should be read the same',
      );
    });

    test('Should read each state X names', () {
      const states = {
        'NotStarted': SpaceState.scheduled,
        'PrePublished': SpaceState.scheduled,
        'Running': SpaceState.live,
        'Ended': SpaceState.ended,
        'TimedOut': SpaceState.ended,
        'Canceled': SpaceState.ended,
      };

      for (final MapEntry(key: named, value: state) in states.entries) {
        expect(
          Space.fromGraphql(_withMetadata(_live(), {'state': named}))?.state,
          state,
          reason: 'X calls a $state space $named',
        );
      }
    });

    test('Should not read a space whose state is unknown', () {
      expect(Space.fromGraphql(_withMetadata(_live(), {})), isNotNull, reason: 'The unchanged space should be read');
      expect(
        Space.fromGraphql(_withMetadata(_live(), {'state': 'SomethingNew'})),
        isNull,
        reason: 'A state QuaX does not know should not be shown as live or ended',
      );
    });

    test('Should not throw when the optional fields are missing', () {
      final space = Space.fromGraphql({
        'data': {
          'audioSpace': {
            'metadata': {'rest_id': '1', 'state': 'Ended'},
            'participants': {
              'admins': 'unexpected',
              'speakers': [null, 'text', {}],
            },
          },
        },
      });

      expect(space?.id, '1', reason: 'The id and the state are all the card needs');
      expect(space?.canPlay, isFalse, reason: 'Without a media key nothing can be played');
      expect(space?.hosts, isEmpty, reason: 'Hosts that are not a list should be ignored');
      expect(space?.speakers, isEmpty, reason: 'Speakers that are not objects with a screen name should be ignored');
      expect(space?.duration, isNull, reason: 'No duration can be shown without both times');
    });
  });
}
