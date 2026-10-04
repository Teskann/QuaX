import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/video_quality.dart';

void main() {
  const qualities = [
    TweetVideoQuality('https://video.x.com/high.mp4', '720p'),
    TweetVideoQuality('https://video.x.com/low.mp4', '360p'),
  ];
  const best = 'https://video.x.com/high.mp4';

  group('downloadUrlFor()', () {
    test('Should download the quality being played', () {
      expect(downloadUrlFor('https://video.x.com/low.mp4', qualities, best), 'https://video.x.com/low.mp4',
          reason: 'Switching to 360p in the player should make the download 360p too');
    });

    test('Should fall back to the best file when the player is not on a listed quality', () {
      expect(downloadUrlFor('https://video.x.com/master.m3u8', qualities, best), best,
          reason: 'An HLS playlist cannot be saved as a video file');
      expect(downloadUrlFor(null, qualities, best), best, reason: 'Without a data source the best file is used');
    });
  });
}
