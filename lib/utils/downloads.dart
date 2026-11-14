import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';

import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/errors.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pref/pref.dart';

Future<void> downloadUriToPickedFile(BuildContext context, Uri uri, String fileName,
    {required BasePrefService prefs, required Function() onStart, required Function() onSuccess}) async {
  var sanitizedFilename = fileName.split("?")[0];

  try {
    onStart();
    var responseTask = downloadFile(context, uri);

    var response = await responseTask;
    if (response == null) {
      return;
    }

    if (await saveToDownloads(prefs, sanitizedFilename, bytes: response)) {
      onSuccess();
    }
  } catch (e) {
    if (context.mounted) {
      showSnackBar(context, icon: '🙊', message: e.toString());
    }
  }
}

/// Saves [bytes], or the file at [sourcePath], where the user keeps downloads. False if the user cancelled.
Future<bool> saveToDownloads(BasePrefService prefs, String fileName, {Uint8List? bytes, String? sourcePath}) async {
  final downloadPath = _downloadDirectory(prefs);
  if (downloadPath == null) {
    final savedPath = await FlutterFileDialog.saveFile(
      params: SaveFileDialogParams(fileName: fileName, data: bytes, sourceFilePath: sourcePath),
    );
    return savedPath != null;
  }

  await _saveToDirectory(downloadPath, fileName, bytes: bytes, sourcePath: sourcePath);
  return true;
}

/// The folder chosen in the settings, or null when the user wants to be asked.
String? _downloadDirectory(BasePrefService prefs) {
  final downloadPath = prefs.get<String>(optionDownloadPath) ?? '';
  return prefs.get(optionDownloadType) == optionDownloadTypeAsk || downloadPath == '' ? null : downloadPath;
}

Future<void> _saveToDirectory(String directory, String fileName, {Uint8List? bytes, String? sourcePath}) async {
  final savedFile = p.join(directory, fileName);
  if (bytes != null) {
    await File(savedFile).writeAsBytes(bytes);
  } else {
    await File(sourcePath!).copy(savedFile);
  }

  // Notify Android's media scanner so the file appears in the gallery
  const platform = MethodChannel('browser_resolver');
  try {
    await platform.invokeMethod('scanMediaFile', {'path': savedFile});
  } catch (_) {}
}

class MediaDownload {
  final Uri uri;
  final String fileName;

  const MediaDownload(this.uri, this.fileName);
}

typedef SaveDownload = Future<void> Function(String fileName, http.Response response);

/// Where a batch of downloads goes: the folder chosen in the settings, else a folder picked once for the whole
/// batch. Null if the user cancelled.
Future<SaveDownload?> pickBatchDestination(BasePrefService prefs) async {
  final downloadPath = _downloadDirectory(prefs);
  if (downloadPath != null) {
    return (fileName, response) => _saveToDirectory(downloadPath, fileName, bytes: response.bodyBytes);
  }

  final directory = await FlutterFileDialog.pickDirectory();
  if (directory == null) {
    return null;
  }
  return (fileName, response) => FlutterFileDialog.saveFileToDirectory(
        directory: directory,
        data: response.bodyBytes,
        fileName: fileName,
        mimeType: response.headers['content-type'],
      );
}

/// Downloads [downloads] one after the other, so a post of 20 media does not flood X. Gives how many were saved.
Future<int> downloadAll(Iterable<MediaDownload> downloads, SaveDownload save, {http.Client? client}) async {
  final httpClient = client ?? http.Client();
  try {
    return await downloads.fold<Future<int>>(
      Future.value(0),
      (saved, download) async => await saved + await _downloadOne(httpClient, download, save),
    );
  } finally {
    if (client == null) httpClient.close();
  }
}

Future<int> _downloadOne(http.Client client, MediaDownload download, SaveDownload save) async {
  try {
    final response = await client.get(download.uri);
    if (response.statusCode != 200) {
      return 0;
    }
    await save(download.fileName, response);
    return 1;
  } catch (_) {
    return 0;
  }
}

class UnableToSaveMedia {
  final Uri uri;
  final Object e;

  UnableToSaveMedia(this.uri, this.e);

  @override
  String toString() {
    return 'Unable to save the media {uri: $uri, e: $e}';
  }
}

Future downloadFile(BuildContext context, Uri uri) async {
  var response = await http.get(uri);
  if (response.statusCode == 200) {
    return response.bodyBytes;
  }

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        L10n.of(context).unable_to_save_the_media_twitter_returned_a_status_of_response_statusCode(response.statusCode),
      ),
    ));
  }

  return null;
}
