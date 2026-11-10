import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/space/space_recording.dart';

import 'recorded_spaces.dart';

// The start of a playlist that X sent for a recorded space
const _playlistStart = '''#EXTM3U
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-TARGETDURATION:4
#EXT-X-VERSION:6
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PROGRAM-DATE-TIME:2026-11-08T18:12:50.881Z
#EXTINF:3.029,
chunk_1794161570986814028_0_b.aac
#EXT-X-PROGRAM-DATE-TIME:2026-11-08T18:12:54.881Z
#EXTINF:2.987,
chunk_1794161570988095088_1_b.aac
''';

final _playlistUri = Uri.parse(
  'https://prod-fastly-p.video.pscp.tv/Transcoding/v1/hls/PJTX/non_transcode/pdxa/periscope-replays-public/'
  'audio-space/playlist_16652571343918088007.m3u8?type=replay',
);

const _adtsFrame = [0xff, 0xf1, 0x4c, 0x80, 0x01, 0x3f, 0xfc];

/// An ID3 tag with [size] bytes, like the ones X sends.
List<int> _id3Tag(int size) => [
  ...'ID3'.codeUnits,
  4,
  0,
  0,
  ...[21, 14, 7, 0].map((shift) => (size >> shift) & 0x7f),
  ...List.filled(size, 0x49),
];

// X starts each chunk with two tags: a timestamp, then metadata
Uint8List _chunk(int audioByte) => Uint8List.fromList([..._id3Tag(63), ..._id3Tag(281), ..._adtsFrame, audioByte]);

void main() {
  group('recordingChunkUris()', () {
    test('Should list the chunk addresses of the playlist, in order, next to it', () {
      final chunkUris = recordingChunkUris(_playlistUri, _playlistStart);

      expect(chunkUris, hasLength(2), reason: 'Only the lines that are not tags are chunk addresses');
      expect(
        chunkUris.first.toString(),
        'https://prod-fastly-p.video.pscp.tv/Transcoding/v1/hls/PJTX/non_transcode/pdxa/periscope-replays-public/'
        'audio-space/chunk_1794161570986814028_0_b.aac',
        reason: 'A chunk address is relative to the playlist',
      );
      expect(
        chunkUris.last.pathSegments.last,
        'chunk_1794161570988095088_1_b.aac',
        reason: 'The chunk addresses keep their order',
      );
    });

    test('Should read a playlist with Windows line endings', () {
      expect(
        recordingChunkUris(_playlistUri, _playlistStart.replaceAll('\n', '\r\n')).first.pathSegments.last,
        'chunk_1794161570986814028_0_b.aac',
        reason: 'The \\r must not end up in the address',
      );
    });
  });

  group('withoutId3Tags()', () {
    test('Should keep only the audio after the tags', () {
      expect(withoutId3Tags(_chunk(1)), [
        ..._adtsFrame,
        1,
      ], reason: 'Tags left between the chunks would sound like noise');
    });

    test('Should keep a chunk without tags as it is', () {
      expect(withoutId3Tags(Uint8List.fromList(_adtsFrame)), _adtsFrame, reason: 'There is nothing to remove');
    });

    test('Should not fail on a cut tag', () {
      expect(withoutId3Tags(Uint8List.fromList(_id3Tag(100).take(40).toList())), isEmpty, reason: 'No audio is left');
    });
  });

  group('recordingFileName()', () {
    test('Should name the file after the host and the space', () {
      final space = spaceOf(recordedSpace(hasPlayableRecording));

      expect(
        recordingFileName(space),
        '${space.hosts.first.screenName}-${space.id}.aac',
        reason: 'Like other downloads, the name starts with the author',
      );
    });
  });
}
