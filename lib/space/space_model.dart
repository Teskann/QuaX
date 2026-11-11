import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_triple/flutter_triple.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pref/pref.dart';
import 'package:quax/client/client.dart';
import 'package:quax/space/space.dart';
import 'package:quax/space/space_recording.dart';
import 'package:quax/utils/downloads.dart';

class SpaceModel extends Store<Space> {
  static final log = Logger('SpaceModel');

  // A feed rebuilds a card each time it scrolls back into view: a space already known shows at once, then refreshes
  static final Map<String, Space> _known = {};

  @visibleForTesting
  static void forgetKnownSpaces() => _known.clear();

  final String id;
  bool _destroyed = false;

  SpaceModel(this.id) : super(_known[id] ?? Space(id: id, title: '', state: SpaceState.scheduled));

  Future<void> load() => _known.containsKey(id) ? _refresh() : _loadUnknown();

  Future<void> _loadUnknown() {
    // execute() waits a moment before it says it is loading, which would show the empty space meanwhile
    setLoading(true);
    return execute(() async => _known[id] = await Twitter.getSpace(id));
  }

  // The known space stays on screen while X answers, and when it cannot
  Future<void> _refresh() async {
    try {
      final space = await Twitter.getSpace(id);
      _known[id] = space;
      if (!_destroyed) update(space);
    } on Exception catch (error) {
      log.warning('Could not refresh the space $id', error);
    }
  }

  @override
  Future destroy() {
    _destroyed = true;
    return super.destroy();
  }
}

class SpaceStreamModel extends Store<String> {
  final String mediaKey;

  SpaceStreamModel(this.mediaKey) : super('');

  Future<void> load() {
    // execute() waits a moment before it says it is loading, which would start a player on an empty playlist meanwhile
    setLoading(true);
    return execute(() => Twitter.getSpacePlaylist(mediaKey));
  }
}

/// How far a download is, from 0 to 1.
class DownloadProgress {
  final double? fraction;

  // A Store ignores null. So "no download" needs its own value.
  const DownloadProgress.none() : fraction = null;

  const DownloadProgress(double this.fraction);

  bool get isRunning => fraction != null;
}

class SpaceDownloadModel extends Store<DownloadProgress> {
  // Kept while the app runs. A page that opens again finds its download.
  static final Map<String, SpaceDownloadModel> _bySpaceId = {};

  static SpaceDownloadModel of(Space space) => _bySpaceId.putIfAbsent(space.id, () => SpaceDownloadModel(space));

  @visibleForTesting
  static void forgetDownloads() => _bySpaceId.clear();

  final Space space;

  SpaceDownloadModel(this.space) : super(const DownloadProgress.none());

  /// False if nothing was saved. The user cancelled, or a download was already running.
  Future<bool> downloadAndSave(BasePrefService prefs) async {
    if (state.isRunning) return false;
    update(const DownloadProgress(0));
    Directory? tempFolder;
    try {
      // One folder per download. So two downloads never share a file.
      tempFolder = await (await getTemporaryDirectory()).createTemp('space');
      final recordingFile = File(p.join(tempFolder.path, recordingFileName(space)));
      await _downloadRecordingTo(recordingFile);
      return await saveToDownloads(prefs, p.basename(recordingFile.path), sourcePath: recordingFile.path);
    } finally {
      await tempFolder?.delete(recursive: true);
      update(const DownloadProgress.none());
    }
  }

  Future<void> _downloadRecordingTo(File recordingFile) async {
    final playlistUri = Uri.parse(await Twitter.getSpacePlaylist(space.mediaKey!));
    final client = http.Client();
    final sink = recordingFile.openWrite();
    try {
      await downloadRecording(client, playlistUri, sink, onProgress: (fraction) => update(DownloadProgress(fraction)));
    } finally {
      await sink.close();
      client.close();
    }
  }
}
