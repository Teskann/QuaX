import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quax/catcher/exceptions.dart' as quax;
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

  group('downloadRecording()', () {
    /// Downloads with a fake clock, so timeouts and retries take no time.
    (List<int>, List<double>) downloadWithFakeClock(http.Client client) => fakeAsync((clock) {
      final writtenAudio = <int>[];
      final progress = <double>[];
      final sinkTarget = StreamController<List<int>>()..stream.listen(writtenAudio.addAll);
      Object? error;
      downloadRecording(
        client,
        _playlistUri,
        IOSink(sinkTarget),
        onProgress: progress.add,
      ).catchError((e) => error = e);
      clock.elapse(const Duration(minutes: 5));
      if (error != null) throw error!;
      return (writtenAudio, progress);
    });

    /// Sends the playlist. Each chunk gets [answer], or its audio if [answer] gives null.
    MockClient recordingServer({Future<http.Response>? Function(String chunkName)? answer}) =>
        MockClient((request) async {
          final name = request.url.pathSegments.last;
          if (name.endsWith('.m3u8')) return http.Response(_playlistStart, 200);
          return await answer?.call(name) ?? http.Response.bytes(_chunk(name.contains('_0_') ? 0 : 1), 200);
        });

    const joinedAudio = [..._adtsFrame, 0, ..._adtsFrame, 1];

    test('Should join the audio of the chunks, in order', () {
      final (audio, progress) = downloadWithFakeClock(recordingServer());

      expect(audio, joinedAudio, reason: 'The file is the audio of each chunk, one after the other');
      expect(progress.last, 1, reason: 'The progress ends at 1');
    });

    test('Should download again a chunk whose connection dropped', () {
      final failedOnce = <String>{};
      final client = recordingServer(
        answer: (chunkName) =>
            failedOnce.add(chunkName) ? Future.error(http.ClientException('Connection closed')) : null,
      );

      expect(
        downloadWithFakeClock(client).$1,
        joinedAudio,
        reason: 'One dropped connection should not fail the download',
      );
    });

    test('Should download again a chunk whose request got stuck', () {
      final stuckOnce = <String>{};
      final client = recordingServer(
        answer: (chunkName) => stuckOnce.add(chunkName) ? Completer<http.Response>().future : null,
      );

      expect(downloadWithFakeClock(client).$1, joinedAudio, reason: 'A request with no answer must not block');
    });

    test('Should download again a chunk when the server failed', () {
      final failedOnce = <String>{};
      final client = recordingServer(
        answer: (chunkName) => failedOnce.add(chunkName) ? Future.value(http.Response('', 503)) : null,
      );

      expect(downloadWithFakeClock(client).$1, joinedAudio, reason: 'A server error (5xx) often goes away');
    });

    test('Should fail when a chunk is refused', () {
      final client = recordingServer(answer: (_) => Future.value(http.Response('', 403)));

      expect(
        () => downloadWithFakeClock(client),
        throwsA(isA<quax.HttpException>()),
        reason: 'A recording with a missing part must not be saved',
      );
    });

    test('Should fail when a chunk still fails after the last attempt', () {
      final client = recordingServer(answer: (_) => Future.error(http.ClientException('Connection closed')));

      expect(
        () => downloadWithFakeClock(client),
        throwsA(isA<http.ClientException>()),
        reason: 'The download must stop at some point',
      );
    });

    test('Should fail when the playlist has no chunk', () {
      final client = MockClient((_) async => http.Response('#EXTM3U\n#EXT-X-ENDLIST\n', 200));

      expect(
        () => downloadWithFakeClock(client),
        throwsA(isA<quax.NotFoundException>()),
        reason: 'An empty file should not be saved as the recording',
      );
    });
  });
}
