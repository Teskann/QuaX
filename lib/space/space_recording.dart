import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:quax/catcher/exceptions.dart' as quax;
import 'package:quax/space/id3_header.dart';
import 'package:quax/space/space.dart';
import 'package:quax/utils/iterables.dart';

const _chunksAtOnce = 8;

const _attempts = 4;

const _timeout = Duration(seconds: 30);

const _retryDelay = Duration(seconds: 1);

/// The audio chunks listed in an HLS playlist, in order.
List<Uri> recordingChunkUris(Uri playlistUri, String playlistText) => playlistText
    .split('\n')
    .map((line) => line.trim())
    .where((line) => line.isNotEmpty && !line.startsWith('#'))
    .map(playlistUri.resolve)
    .toList(growable: false);

/// The audio of a chunk, without the ID3 tags at its start.
Uint8List withoutId3Tags(Uint8List chunkBytes) {
  final header = Id3Header.read(chunkBytes);
  // There can be more than one tag. So we call this again on what is left.
  return header == null ? chunkBytes : withoutId3Tags(_skip(chunkBytes, header.tagLength));
}

Uint8List _skip(Uint8List bytes, int count) {
  // A cut tag can give a size bigger than the chunk.
  return Uint8List.sublistView(bytes, min(count, bytes.length));
}

String recordingFileName(Space space) => '${space.hosts.firstOrNull?.screenName ?? 'space'}-${space.id}.aac';

/// Writes the audio of [playlistUri] to [sink]. [onProgress] gets a value from 0 to 1.
Future<void> downloadRecording(
  http.Client client,
  Uri playlistUri,
  IOSink sink, {
  required void Function(double progress) onProgress,
}) async {
  final playlistText = (await _getWithRetries(client, playlistUri)).body;
  final chunkUris = recordingChunkUris(playlistUri, playlistText);
  if (chunkUris.isEmpty) throw quax.NotFoundException();

  // We download a few chunks at the same time
  final uriBatches = chunkUris.slices(_chunksAtOnce);
  for (final (index, batchUris) in uriBatches.indexed) {
    final chunkAudios = await Future.wait(batchUris.map((chunkUri) => _chunkAudio(client, chunkUri)));
    chunkAudios.forEach(sink.add);
    // Fails at once if the disk is full.
    await sink.flush();
    onProgress((index + 1) / uriBatches.length);
  }
}

Future<Uint8List> _chunkAudio(http.Client client, Uri chunkUri) async {
  final response = await _getWithRetries(client, chunkUri);
  return withoutId3Tags(response.bodyBytes);
}

// On mobile data, some requests fail. So we try again.
Future<http.Response> _getWithRetries(http.Client client, Uri uri) async {
  for (var attempt = 1; ; attempt++) {
    final isLastAttempt = attempt == _attempts;
    try {
      final response = await client.get(uri).timeout(_timeout);
      if (response.statusCode == 200) return response;
      // Only a server error (5xx) may go away. A 403 or a 404 stays.
      if (response.statusCode < 500 || isLastAttempt) throw quax.HttpException(response);
    } on http.ClientException {
      if (isLastAttempt) rethrow;
    } on IOException {
      if (isLastAttempt) rethrow;
    } on TimeoutException {
      if (isLastAttempt) rethrow;
    }
    await Future.delayed(_retryDelay * attempt);
  }
}
