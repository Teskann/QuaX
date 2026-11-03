// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:puppeteer/puppeteer.dart';
import 'chrome.dart';

/// Written by this script, not by capture.dart, which must leave it alone.
final transactionIdFixtures = Directory('test/fixtures/XClientTransactionId');

const _requests = [
  ('GET', '/i/api/graphql/lSMmQoIyV1rw8qoyU9pQ5g/SearchTimeline'),
  ('POST', '/i/api/graphql/6fDZvDa5qNz7RBq-iK4cXQ/FavoriteTweet'),
];

const _origin = 'https://quax.test';


const _signInPage = '''
async (html, nowMs, requests) => {
  const parsed = new DOMParser().parseFromString(html, 'text/html');
  parsed.querySelectorAll('script').forEach((script) => script.remove());
  document.replaceChild(document.adoptNode(parsed.documentElement), document.documentElement);
  Date.now = () => nowMs;
  const module = await import('/sign.js');
  const sign = await module.default();
  const ids = [];
  for (const [method, path] of requests) ids.push(await sign(path, method));
  return ids;
}
''';

/// Every script Chrome downloads: X names them by a hash only, so the files
/// to keep are told apart by their content.
final _recordedScripts = RegExp(r'^https://abs\.twimg\.com/.*\.js$');

final _entryScript = RegExp(r'/entry-client[\w-]*\.js$');

final _staticImport = RegExp(r'''from\s*["'](\.[./\w-]*\.js)["']''');

/// The sign module reads its key bytes as hexadecimal numbers, e.g. `(t[39],16)`.
final _signModuleCode = RegExp(r'\(\w\[\d{1,2}\],\s*16\)');

const _port = 9334;
const _loadTimeout = Duration(seconds: 20);
const _homePage = 'https://x.com/home';

Future<void> main() async {
  transactionIdFixtures.createSync(recursive: true);
  print('Loading x.com in Chrome and recording the files it downloads…');
  final sources = await _recordInChrome();
  sources.writeTo(transactionIdFixtures);
  print('Recorded ${sources.files.length} file(s): ${sources.files.keys.join(', ')}');

  final signUrl = sources.files.keys.firstWhereOrNull((url) => _isSignModule(url, sources.files[url]!));
  if (signUrl == null) {
    print('\nChrome downloaded no sign module. Read the recorded files in ${transactionIdFixtures.path}/ to see how');
    print('X loads it now, then adapt _signModuleCode.');
    return;
  }
  await _recordSignedIds(sources.files[_homePage]!, sources.files[signUrl]!);
}

/// A real, logged-out Chrome: the app gets the same page, and X refuses a
/// browser started by puppeteer's launcher.
Future<_Sources> _recordInChrome() async {
  final profile = Directory.systemTemp.createTempSync('quax-transaction-id');
  final chrome = await startChrome(profile: profile, port: _port);
  final browser = await connectChrome(_port);
  try {
    final page = (await browser.pages).first;
    final bodies = <String, String>{};
    page.onResponse.listen((response) {
      final isPage = response.request.resourceType == ResourceType.document && response.status == 200;
      final url = isPage && response.url.startsWith('https://x.com/') ? _homePage : response.url;
      if (url == _homePage || _recordedScripts.hasMatch(url)) {
        response.text.then((text) => bodies[url] = text, onError: (_) => bodies[url] = '');
      }
    });
    // Never Until.networkIdle: x.com keeps polling, so "idle" may never come.
    try {
      await page.goto(_homePage, wait: Until.domContentLoaded, timeout: _loadTimeout);
    } on Exception catch (error) {
      print('Page did not finish loading ($error), keeping what arrived.');
    }
    await _waitFor(() => bodies.entries.any((file) => _isSignModule(file.key, file.value)));
    return _Sources(_onTheWayToSignModule(Map.of(bodies)));
  } finally {
    browser.disconnect();
    chrome.kill();
    await chrome.exitCode;
    profile.deleteSync(recursive: true);
  }
}

bool _isSignModule(String url, String text) => url != _homePage && _signModuleCode.hasMatch(text);

/// The files the app may read to reach the sign module: the page, the entry
/// script, every module the entry script imports, and the sign module.
Map<String, String> _onTheWayToSignModule(Map<String, String> files) {
  final entries = files.keys.where(_entryScript.hasMatch).toList();
  final imports = entries.expand((entry) => _staticImport
      .allMatches(files[entry]!)
      .map((match) => Uri.parse(entry).resolve(match.group(1)!).toString()));
  final signModules = files.keys.where((url) => _isSignModule(url, files[url]!));
  return {
    for (final url in {_homePage, ...entries, ...imports, ...signModules})
      if (files[url] != null) url: files[url]!,
  };
}

/// The sign module is imported lazily, a moment after the page itself.
Future<void> _waitFor(bool Function() condition) async {
  final deadline = DateTime.now().add(_loadTimeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future.delayed(const Duration(milliseconds: 250));
  }
}

class _Sources {
  const _Sources(this.files);

  /// URL -> content. The x.com page is stored under the URL the app asks for.
  final Map<String, String> files;

  /// Replaces the files of an earlier recording, except `expected.json`.
  void writeTo(Directory directory) {
    directory
        .listSync()
        .whereType<File>()
        .where((file) => !file.path.endsWith('/expected.json'))
        .forEach((file) => file.deleteSync());
    final names = {for (final url in files.keys) url: url == _homePage ? 'home.html' : Uri.parse(url).pathSegments.last};
    names.forEach((url, name) => File('${directory.path}/$name').writeAsStringSync(files[url]!));
    File('${directory.path}/sources.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(names));
  }
}

Future<void> _recordSignedIds(String homePageHtml, String signFileText) async {
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  print('Signing ${_requests.length} requests in Chrome…');
  final ids = await _signInChrome(homePageHtml, signFileText, nowMs);
  File('${transactionIdFixtures.path}/expected.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'nowMs': nowMs,
    'cases': [
      for (final ((method, path), id) in _requests.indexed.map((e) => (e.$2, ids[e.$1])))
        {'method': method, 'path': path, 'transactionId': id},
    ],
  }));
  print('Written to ${transactionIdFixtures.path}. Now run:\n  fvm flutter test test/client/x_client_transaction_id/');
}

Future<List<String>> _signInChrome(String html, String signModule, int nowMs) async {
  final browser = await puppeteer.launch(executablePath: installedChrome());
  try {
    final page = await browser.newPage();
    await page.setRequestInterception(true);
    page.onRequest.listen((request) => request.url == '$_origin/sign.js'
        ? request.respond(contentType: 'text/javascript', body: signModule)
        : request.respond(contentType: 'text/html', body: ''));
    await page.goto('$_origin/');
    final ids = await page.evaluate<List<dynamic>>(_signInPage, args: [
      html,
      nowMs,
      [for (final (method, path) in _requests) [method, path]],
    ]);
    return ids.cast<String>();
  } finally {
    await browser.close();
  }
}
