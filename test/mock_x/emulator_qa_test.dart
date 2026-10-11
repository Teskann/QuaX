import 'package:flutter_test/flutter_test.dart';

import '../../tool/mock_x/app_preferences.dart';
import '../../tool/mock_x/video_cut.dart';

void main() {
  group('sharedPreferencesXml()', () {
    test('Should write each boolean under the key the pref package reads', () {
      final xml = sharedPreferencesXml({'onboarding.done': true, 'should_check_for_updates': false});

      expect(xml, contains('<boolean name="flutter.pref_onboarding.done" value="true" />'),
          reason: 'shared_preferences prefixes keys with "flutter.", and QuaX gives the pref package the prefix "pref_"');
      expect(xml, contains('<boolean name="flutter.pref_should_check_for_updates" value="false" />'),
          reason: 'A false value must be written too, or the default would apply');
    });

    test('Should write a well-formed Android preferences file', () {
      final lines = sharedPreferencesXml({'onboarding.done': true}).trim().split('\n');

      expect(lines.first, startsWith('<?xml'), reason: 'Android reads the file as XML');
      expect(lines[1], '<map>', reason: 'Android stores the preferences in a single <map>');
      expect(lines.last, '</map>', reason: 'The <map> must be closed for Android to read any preference');
    });
  });

  group('cutPoint()', () {
    const freezedetect = '''
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'browse_profile.mp4':
  Duration: 00:00:31.92, start: 0.000000, bitrate: 2561 kb/s
[freezedetect @ 0x743d] lavfi.freezedetect.freeze_start: 0.326333
[freezedetect @ 0x743d] lavfi.freezedetect.freeze_duration: 5.7492
[freezedetect @ 0x743d] lavfi.freezedetect.freeze_end: 6.075533
[freezedetect @ 0x743d] lavfi.freezedetect.freeze_start: 6.492467
[freezedetect @ 0x743d] lavfi.freezedetect.freeze_end: 7.758467
''';

    test('Should start half a second before the still screen of the start ends', () {
      expect(cutPoint(freezedetect), const Duration(microseconds: 5575533),
          reason: 'The first still ends when the app reacts, and the margin shows the screen before it');
    });

    test('Should keep the whole video when it does not start on a still screen', () {
      expect(
          cutPoint('[freezedetect @ 0x743d] lavfi.freezedetect.freeze_start: 4.2\n'
              '[freezedetect @ 0x743d] lavfi.freezedetect.freeze_end: 9.8\n'),
          isNull,
          reason: 'A still in the middle of a flow is the app waiting, which the video must show');
    });

    test('Should keep the whole video when the screen never moves again', () {
      expect(cutPoint('[freezedetect @ 0x743d] lavfi.freezedetect.freeze_start: 0.3\n'), isNull,
          reason: 'Without the end of the still there is no point where the app starts reacting');
    });

    test('Should keep the whole video when the still ends within the first half second', () {
      expect(
          cutPoint('[freezedetect @ 0x743d] lavfi.freezedetect.freeze_start: 0\n'
              '[freezedetect @ 0x743d] lavfi.freezedetect.freeze_end: 0.3\n'),
          isNull,
          reason: 'There is no still screen to cut, and re-encoding the video would be wasted');
    });
  });
}
