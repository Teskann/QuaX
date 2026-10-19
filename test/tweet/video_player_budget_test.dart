import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/video_player_budget.dart';

void main() {
  group('videoPlayerBudget()', () {
    test('Should allow 5 players on a Pixel 6', () {
      expect(videoPlayerBudget(heapLimitMb: 256, maxHardwareDecoders: 16), 5,
          reason: 'A Pixel 6 has a 256 MB Java heap: 6 players buffering whole GIFs crashed it, '
              'so the budget must stay below that while keeping several GIFs animated');
    });

    test('Should allow fewer players on a device with a smaller heap', () {
      expect(videoPlayerBudget(heapLimitMb: 192, maxHardwareDecoders: 16), 3,
          reason: 'Each player takes its buffer on the Java heap, so a smaller heap affords fewer');
    });

    test('Should always allow at least one player', () {
      expect(videoPlayerBudget(heapLimitMb: 64, maxHardwareDecoders: 1), 1,
          reason: 'Even the weakest device must be able to play the video the user opens');
    });

    test('Should not allow more players than hardware decoders', () {
      expect(videoPlayerBudget(heapLimitMb: 512, maxHardwareDecoders: 2), 2,
          reason: 'A player without a hardware decoder fails to start, so they are a hard limit');
    });

    test('Should ignore an unknown number of hardware decoders', () {
      expect(videoPlayerBudget(heapLimitMb: 256, maxHardwareDecoders: 0), 5,
          reason: 'Some devices report no hardware decoder at all, the heap is then the only limit');
    });

    test('Should cap the number of players on devices with a huge heap', () {
      expect(videoPlayerBudget(heapLimitMb: 1024, maxHardwareDecoders: 32), 8,
          reason: 'Every player also costs a decoder, CPU and battery, so there is a ceiling');
    });
  });

  group('maxBufferMsFor()', () {
    test('Should buffer less of a video with a higher bitrate', () {
      expect(maxBufferMsFor(10000000), lessThan(maxBufferMsFor(2000000)),
          reason: 'The buffer is limited in bytes, so a heavier video fits fewer seconds');
    });

    test('Should keep the buffer of a video within the bytes allowed per player', () {
      const bitrate = 8000000;
      final bytes = maxBufferMsFor(bitrate) * bitrate ~/ 8 ~/ 1000;

      expect(bytes, lessThanOrEqualTo(videoBufferBytesPerPlayer),
          reason: 'Buffering more than that is what filled the Java heap and crashed the app');
    });

    test('Should assume a typical bitrate when X gives none', () {
      expect(maxBufferMsFor(0), maxBufferMsFor(null),
          reason: 'X gives GIFs a bitrate of 0, which must not be taken literally (division by 0)');
      expect(maxBufferMsFor(null), inInclusiveRange(2500, 600000),
          reason: 'An unknown bitrate should still give a usable buffer');
    });
  });

  group('isDecoderFailure()', () {
    test('Should recognize a decoder that could not be allocated', () {
      expect(
          isDecoderFailure('Video player had error androidx.media3.exoplayer.ExoPlaybackException: '
              'MediaCodecVideoRenderer error, index=0, format=Format(1, null, video/avc), format_supported=YES'),
          isTrue,
          reason: 'This is how the player reports a decoder it could not start, the case where '
              'freeing another player can help');
    });

    test('Should not mistake a network error for a decoder failure', () {
      expect(isDecoderFailure('Video player had error androidx.media3.exoplayer.ExoPlaybackException: Source error'),
          isFalse,
          reason: 'Freeing another player does not help when the video cannot be downloaded');
    });
  });
}
