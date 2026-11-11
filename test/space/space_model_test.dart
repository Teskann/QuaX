import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart' show AbstractTwitterClient;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:pref/pref.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/space/space_model.dart';

import 'recorded_spaces.dart';

/// X never answers, so a store stays loading.
class _SilentX extends AbstractTwitterClient {
  @override
  Future<Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) => Completer<Response>().future;

  @override
  Future<Response> post(Uri uri, {Map<String, String>? headers, dynamic body, Encoding? encoding, Duration? timeout}) =>
      Completer<Response>().future;

  @override
  Future<Response> multipartRequest(
    Uri uri, {
    List<MultipartFile>? files,
    Map<String, String>? headers,
    Duration? timeout,
  }) => Completer<Response>().future;
}

/// X gives the address of the recording.
class _StreamOfX extends _SilentX {
  @override
  Future<Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) async => Response(
    jsonEncode({
      'source': {'noRedirectPlaybackUrl': 'https://video.pscp.tv/audio-space/playlist_1.m3u8?type=replay'},
    }),
    200,
  );
}

// A playlist of one chunk, with one byte of audio
final _recordingServer = MockClient(
  (request) async => request.url.path.endsWith('.m3u8')
      ? Response('#EXTM3U\n#EXTINF:3.0,\nchunk_0.aac\n', 200)
      : Response.bytes([1], 200),
);

final _refusingServer = MockClient((_) async => Response('', 403));

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');
const _fileDialog = MethodChannel('flutter_file_dialog');

Future<Directory> _temporaryFolder() async {
  final folder = await Directory.systemTemp.createTemp('space_model_test');
  addTearDown(() => folder.delete(recursive: true));
  return folder;
}

/// Uses [temporaryFolder] as the temporary folder. The save dialog returns [savedPath].
void _mockDevice(Directory temporaryFolder, {String? savedPath}) {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_pathProvider, (_) async => temporaryFolder.path);
  messenger.setMockMethodCallHandler(_fileDialog, (_) async => savedPath);
  addTearDown(() {
    messenger.setMockMethodCallHandler(_pathProvider, null);
    messenger.setMockMethodCallHandler(_fileDialog, null);
  });
}

PrefServiceCache _prefsSavingTo(Directory downloads) =>
    PrefServiceCache(defaults: {optionDownloadType: optionDownloadTypeDirectory, optionDownloadPath: downloads.path});

PrefServiceCache _prefsAskingWhere() => PrefServiceCache(defaults: {optionDownloadType: optionDownloadTypeAsk});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => Twitter.client = _SilentX());

  test('Should say a space is loading as soon as it is asked for', () {
    final model = SpaceModel('1')..load();

    expect(
      model.isLoading,
      isTrue,
      reason: 'Until X answers, the card would show an empty space that has not started yet',
    );
  });

  test('Should say the audio of a space is loading as soon as it is asked for', () {
    final model = SpaceStreamModel('28_1')..load();

    expect(model.isLoading, isTrue, reason: 'Until X answers, the player would start on an empty playlist');
  });

  group('SpaceDownloadModel', () {
    late Directory temporaryFolder;
    late SpaceDownloadModel model;

    setUp(() async {
      temporaryFolder = await _temporaryFolder();
      Twitter.client = _StreamOfX();
      model = SpaceDownloadModel(spaceOf(recordedSpace(hasPlayableRecording)));
    });

    test('Should save the recording, then be idle again', () async {
      _mockDevice(temporaryFolder);
      final downloads = await _temporaryFolder();

      final saved = await runWithClient(() => model.downloadAndSave(_prefsSavingTo(downloads)), () => _recordingServer);

      expect(saved, isTrue, reason: 'The recording goes to the download folder');
      final files = downloads.listSync().whereType<File>();
      expect(files.single.readAsBytesSync(), [1], reason: 'The saved file holds the audio of the recording');
      expect(temporaryFolder.listSync(), isEmpty, reason: 'The temporary file is deleted once saved');
      expect(model.state.isRunning, isFalse, reason: 'The button should come back');
    });

    test('Should say nothing was saved when the user cancels', () async {
      _mockDevice(temporaryFolder, savedPath: null);

      final saved = await runWithClient(() => model.downloadAndSave(_prefsAskingWhere()), () => _recordingServer);

      expect(saved, isFalse, reason: 'No "saved" message should show after a cancel');
      expect(temporaryFolder.listSync(), isEmpty, reason: 'The temporary file is deleted after a cancel too');
    });

    test('Should be idle again, with no file left, when the download fails', () async {
      _mockDevice(temporaryFolder);

      await expectLater(
        runWithClient(() => model.downloadAndSave(_prefsAskingWhere()), () => _refusingServer),
        throwsA(anything),
        reason: 'The page shows the error',
      );
      expect(model.state.isRunning, isFalse, reason: 'The user can try again');
      expect(temporaryFolder.listSync(), isEmpty, reason: 'A failed download leaves no file behind');
    });

    test('Should not start a second download of the same space', () async {
      _mockDevice(temporaryFolder);
      final downloads = await _temporaryFolder();

      final first = runWithClient(() => model.downloadAndSave(_prefsSavingTo(downloads)), () => _recordingServer);
      final second = await model.downloadAndSave(_prefsSavingTo(downloads));
      await first;

      expect(second, isFalse, reason: 'Two downloads would share one file');
    });
  });
}
