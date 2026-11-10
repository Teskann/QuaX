import 'dart:math';
import 'dart:typed_data';

import 'package:quax/space/id3_header.dart';
import 'package:quax/space/space.dart';

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
