import 'dart:io';

import 'package:flutter/material.dart';
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

    final downloadType = prefs.get(optionDownloadType);
    final downloadPath = prefs.get(optionDownloadPath);

    // If the user wants to pick a file every time a download happens
    if (downloadType == optionDownloadTypeAsk || downloadPath == '') {
      var fileInfo =
          await FlutterFileDialog.saveFile(params: SaveFileDialogParams(fileName: sanitizedFilename, data: response));
      if (fileInfo == null) {
        return;
      }

      onSuccess();
      return;
    }

    // Finally, save to the user-defined directory
    var savedFile = p.join(downloadPath, sanitizedFilename);
    await File(savedFile).writeAsBytes(response);

    // Notify Android's media scanner so the file appears in the gallery
    const platform = MethodChannel('browser_resolver');
    try {
      await platform.invokeMethod('scanMediaFile', {'path': savedFile});
    } catch (_) {}

    onSuccess();
  } catch (e) {
    showSnackBar(context, icon: '🙊', message: e.toString());
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
