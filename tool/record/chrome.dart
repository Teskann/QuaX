// ignore_for_file: avoid_print
//
// Starts Chrome as a plain process — not through puppeteer's launcher — and
// connects to it over the debugging port. That matters: puppeteer's launcher
// adds --enable-automation, which X reads and answers by limiting the account
// (capture.dart) or by refusing the page (transaction_id.dart).

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:puppeteer/puppeteer.dart';

/// Starts Chrome the way a person would, plus the debugging port. No
/// --enable-automation, so nothing announces the browser as driven.
Future<Process> startChrome({required Directory profile, required int port}) async {
  final executable = await _chromeExecutable();
  print('Starting $executable on port $port');
  final process = await Process.start(executable, [
    '--remote-debugging-port=$port',
    '--user-data-dir=${profile.absolute.path}',
    '--no-first-run',
    '--no-default-browser-check',
    '--start-maximized',
    // Opens a blank page rather than Chrome's new-tab page. The new-tab page
    // fetches its own content and is briefly not a real frame, which makes
    // connect() fail with "No frame for given id found" as it enumerates pages.
    'about:blank',
  ]);
  await _waitForPort(port);
  return process;
}

/// Chrome opens the port a moment after the process starts, so connecting
/// immediately fails with "connection refused".
Future<void> _waitForPort(int port) async {
  final client = HttpClient();
  for (var attempt = 0; attempt < 40; attempt++) {
    try {
      final request = await client.get('localhost', port, '/json/version');
      await (await request.close()).drain<void>();
      client.close();
      return;
    } on SocketException {
      await Future.delayed(Duration(milliseconds: 500));
    }
  }
  client.close();
  print('Chrome never opened port $port. Is another Chrome already using it?');
  exit(1);
}

/// Throws the last error when Chrome cannot be reached.
Future<Browser> connectChrome(int port) async {
  Object? lastError;
  // Chrome answers on the port before its first tab is fully attachable, so a
  // single attempt races with the browser's own start-up.
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      return await puppeteer.connect(browserUrl: 'http://localhost:$port', defaultViewport: null);
    } on Exception catch (error) {
      if (attempt == 0) print('Chrome is not attachable yet, retrying…');
      lastError = error;
      await Future.delayed(Duration(seconds: 1));
    }
  }
  throw lastError!;
}

/// Prefers an installed Chrome, and otherwise reuses the one puppeteer keeps in
/// its cache — downloading it on the first run only.
Future<String> _chromeExecutable() async {
  final installed = installedChrome();
  if (installed != null) return installed;

  print('No system Chrome found, using the one puppeteer manages…');
  return (await downloadChrome()).executablePath;
}

String? installedChrome() {
  final fromEnv = Platform.environment['CHROME_PATH'];
  if (fromEnv != null && File(fromEnv).existsSync()) return fromEnv;

  const candidates = [
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/snap/bin/chromium',
  ];
  return candidates.firstWhereOrNull((path) => File(path).existsSync());
}
