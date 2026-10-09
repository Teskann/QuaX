import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';

import '../fixtures.dart';

TweetStatus photoTimeline(String name) {
  var counter = 0;
  return Twitter.createUnconversationedChains(
    fixture('UserPhotoTimeline', name).body,
    'tweet',
    const [],
    false,
    true,
    true,
    () => counter,
    () => counter++,
  );
}

void main() {
  group('isProfileGridEntry', () {
    test('Should accept a video grid entry', () {
      expect(Twitter.isProfileGridEntry('profile-grid-0'), isTrue,
          reason: 'The videos tab sends its items as profile-grid-');
    });

    test('Should accept a photo grid entry', () {
      expect(Twitter.isProfileGridEntry('profile-photo-grid-1-tweet-1'), isTrue,
          reason: 'The photos tab sends its items as profile-photo-grid-');
    });

    test('Should reject other entries', () {
      for (final id in ['tweet-1', 'cursor-bottom-1', 'profile-conversation-1', 'profile-photo', '']) {
        expect(Twitter.isProfileGridEntry(id), isFalse, reason: '"$id" is not a media grid item');
      }
    });
  });

  group('Photo tab pagination', () {
    test('Should keep the photos of a page sent as TimelineAddToModule', () {
      final ids = photoTimeline('2095909295913103360-page2-module').chains.expand((c) => c.tweets).map((t) => t.idStr);

      expect(ids, ['2095922394959421815', '2095920289687150903'],
          reason: 'Photos on page 2 and later were dropped, so the tab stopped after the first page');
    });

    test('Should keep the bottom cursor of a page sent as TimelineAddToModule', () {
      expect(photoTimeline('2095909295913103360-page2-module').cursorBottom,
          'DAAHCgABHT0JR6t___8LAAIAAAATMjA5NTkxODUzNTE1OTQ3MjQ0MggAAwAAAAIAAA',
          reason: 'Without the bottom cursor the next page is never requested');
    });

    test('Should return no photos for a page with only cursors', () {
      expect(photoTimeline('2095909295913103360-page2').chains, isEmpty,
          reason: 'An empty page holds nothing to show');
    });
  });
}
