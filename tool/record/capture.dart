// ignore_for_file: avoid_print
//
// Opens each scenario of tool/record/links.json in Chrome and saves every X
// GraphQL response it sees as a fixture under test/fixtures/<Operation>/.
// The scenario description is copied into the fixture, so a test can say why
// the fixture exists without anyone going back to the JSON.
//
//   fvm dart run tool/record/capture.dart            starts Chrome and drives it
//   fvm dart run tool/record/capture.dart --attach    uses a Chrome already open
//
// Chrome is started as a plain process — not through puppeteer's launcher — and
// then driven over the debugging port. That matters: puppeteer's launcher adds
// --enable-automation, which X reads on the login page and answers by limiting
// the account. Started this way, the browser looks like any other.
//
// It gets its own profile in tool/record/.chrome-profile, both because the
// debugging port is refused on Chrome's default profile since version 136, and
// because that profile holds the session and must stay out of git.

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:puppeteer/puppeteer.dart';

import 'transaction_id.dart' show transactionIdFixtures;

/// Response headers worth keeping. An allow-list, so a header X adds tomorrow
/// is dropped by default instead of leaking into a public repository.
const _keepHeaders = {
  'content-type',
  'x-rate-limit-limit',
  'x-rate-limit-remaining',
  'x-rate-limit-reset',
};

/// A body matching any of these is never written: the repository is public and
/// these all mean "someone's session ended up in a file".
final _secrets = <RegExp, String>{
  RegExp(r'\bauth_token\b'): 'session cookie',
  RegExp(r'\bct0\b'): 'CSRF cookie',
  RegExp(r'Bearer\s+AAAA', caseSensitive: false): 'bearer token',
  RegExp(r'\bset-cookie\b', caseSensitive: false): 'Set-Cookie header',
};

final _graphql = RegExp(r'/i/api/graphql/([\w-]+)/(\w+)');

final _linksFile = File('tool/record/links.json');
final _profileDir = Directory('tool/record/.chrome-profile');
final _outDir = Directory('test/fixtures');

/// Every operation seen, and how many responses each produced. Reported at the
/// end so a new endpoint never goes unnoticed.
final _seen = <String, int>{};

/// Pages that never loaded. A run that lost half its scenarios must not be
/// allowed to delete the fixtures those scenarios used to produce.
var _failures = 0;

/// Path -> the variables it was written for. Several links hit the same
/// endpoint: a profile and its Following tab both call UserByScreenName, and
/// the first, most specific one should win. But /all and ?sort=popular may hit
/// it with *different* variables, and those are different fixtures, so they get
/// their own file rather than being dropped.
final _writtenThisRun = <String, String>{};

const _port = 9222;

/// A page that has not reached domContentLoaded in this long is not going to.
const _pageTimeout = Duration(seconds: 15);

/// A page is done when it has stopped calling the API for this long. Waiting on
/// silence beats sleeping a fixed amount that is too long for a quiet page and
/// too short for a slow one.
const _quiet = Duration(milliseconds: 1200);
const _settleCap = Duration(seconds: 8);

/// Chrome sometimes never finishes a body; these keep one such response from
/// holding the whole run.
const _bodyTimeout = Duration(seconds: 10);
const _drainTimeout = Duration(seconds: 10);

class Scenario {
  Scenario(this.url, this.description);

  final String url;
  final String description;
}

Future<void> main(List<String> args) async {
  if (!_linksFile.existsSync()) {
    print('No ${_linksFile.path}.');
    exit(1);
  }
  final scenarios = _readScenarios(_readLinks());
  if (scenarios.isEmpty) {
    print('No scenarios in ${_linksFile.path}.');
    exit(1);
  }

  final attach = args.contains('--attach');
  final chrome = attach ? null : await _startChrome();
  final browser = await _connect(attach);
  final page = (await browser.pages).firstOrNull ?? await browser.newPage();
  await _requireLogin(page);

  var written = 0;
  for (final (index, scenario) in scenarios.indexed) {
    print('\n[${index + 1}/${scenarios.length}] ${scenario.description}');
    print('         ${scenario.url}');
    written += await _visit(page, scenario);
  }

  browser.disconnect();
  chrome?.kill();

  print('\n$written fixtures under ${_outDir.path}');
  _prune();
  final names = _seen.keys.toList()..sort();
  print('\n${names.length} distinct operations recorded:');
  for (final name in names) {
    print('  ${name.padRight(30)} ${_seen[name]} response(s)');
  }
}

/// A profile directory can exist and be logged out, and every capture made in
/// that state records the logged-out site — so the session is checked, not
/// assumed. The check can be wrong, though, so it never has the last word: you
/// can tell it you are logged in and it believes you.
Future<void> _requireLogin(Page page) async {
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      await page.goto('https://x.com/home', wait: Until.domContentLoaded, timeout: _pageTimeout);
      await Future.delayed(Duration(seconds: 2)); // let the client-side redirect settle
    } on Exception catch (error) {
      print('Could not open x.com/home: $error');
    }
    if (await _looksLoggedIn(page)) {
      print('Session confirmed.');
      return;
    }

    print('\nCould not confirm a session — landed on ${page.url}');
    print('Cookies seen for x.com: ${await _cookieNames(page)}');
    stdout.write('Log in in the Chrome window and press Enter, or type y if you already are: ');
    final answer = stdin.readLineSync()?.trim().toLowerCase();
    if (answer == 'y' || answer == 'o') {
      print('Taking your word for it.');
      return;
    }
  }
  print('\nGiving up on the session check. Re-run and answer y to capture anyway.');
  exit(1);
}

/// Two independent signals, because either can be wrong on its own: the session
/// cookie, and the fact that x.com/home did not bounce a logged-out visitor.
Future<bool> _looksLoggedIn(Page page) async {
  final cookies = await page.cookies(urls: ['https://x.com', 'https://twitter.com']);
  if (cookies.any((cookie) => cookie.name == 'auth_token' && cookie.value.isNotEmpty)) {
    return true;
  }
  return page.url?.contains('/home') ?? false;
}

/// Names only. The values are the session itself and must not reach a terminal
/// buffer, a scrollback file or a pasted bug report.
Future<String> _cookieNames(Page page) async {
  final cookies = await page.cookies(urls: ['https://x.com']);
  if (cookies.isEmpty) return 'none';
  return cookies.map((cookie) => cookie.name).join(', ');
}

/// Starts Chrome the way a person would, plus the debugging port. No
/// --enable-automation, so nothing announces the browser as driven.
Future<Process> _startChrome() async {
  final executable = await _chromeExecutable();
  print('Starting $executable on port $_port');
  final process = await Process.start(executable, [
    '--remote-debugging-port=$_port',
    '--user-data-dir=${_profileDir.absolute.path}',
    '--no-first-run',
    '--no-default-browser-check',
    '--start-maximized',
    // Opens a blank page rather than Chrome's new-tab page. The new-tab page
    // fetches its own content and is briefly not a real frame, which makes
    // connect() fail with "No frame for given id found" as it enumerates pages.
    'about:blank',
  ]);
  await _waitForPort();
  return process;
}

/// Chrome opens the port a moment after the process starts, so connecting
/// immediately fails with "connection refused".
Future<void> _waitForPort() async {
  final client = HttpClient();
  for (var attempt = 0; attempt < 40; attempt++) {
    try {
      final request = await client.get('localhost', _port, '/json/version');
      await (await request.close()).drain<void>();
      client.close();
      return;
    } on SocketException {
      await Future.delayed(Duration(milliseconds: 500));
    }
  }
  client.close();
  print('Chrome never opened port $_port. Is another Chrome already using it?');
  exit(1);
}

Future<Browser> _connect(bool attach) async {
  Object? lastError;
  // Chrome answers on the port before its first tab is fully attachable, so a
  // single attempt races with the browser's own start-up.
  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      return await puppeteer.connect(browserUrl: 'http://localhost:$_port', defaultViewport: null);
    } on Exception catch (error) {
      if (attempt == 0) print('Chrome is not attachable yet, retrying…');
      lastError = error;
      await Future.delayed(Duration(seconds: 1));
    }
  }

  {
    final error = lastError;
    print('\nCould not reach Chrome on port $_port: $error');
    if (attach) {
      print('\n--attach expects a Chrome already started with:');
      print('  ${_installedChrome() ?? 'google-chrome'} \\');
      print('    --remote-debugging-port=$_port \\');
      print('    --user-data-dir=${_profileDir.absolute.path}');
      print('\nNote that the flag is ignored if Chrome is already running, and');
      print('refused on the default profile since Chrome 136 — hence the profile above.');
      print('\nOr just drop --attach and let the script start Chrome itself.');
    }
    exit(1);
  }
}

Map<String, dynamic> _readLinks() =>
    jsonDecode(_linksFile.readAsStringSync()) as Map<String, dynamic>;

List<Scenario> _readScenarios(Map<String, dynamic> root) =>
    (root['scenarios'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map((entry) => Scenario(entry['url'] as String, entry['description'] as String? ?? ''))
        .toList();


/// Prefers an installed Chrome, and otherwise reuses the one puppeteer keeps in
/// its cache — downloading it on the first run only.
Future<String> _chromeExecutable() async {
  final installed = _installedChrome();
  if (installed != null) return installed;

  print('No system Chrome found, using the one puppeteer manages…');
  return (await downloadChrome()).executablePath;
}

String? _installedChrome() {
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

/// Loads one scenario, scrolls a few times so the cursor pages are requested
/// too, and saves every GraphQL response seen along the way.
Future<int> _visit(Page page, Scenario scenario) async {
  final captured = <String, Map<String, dynamic>>{};
  final pending = <Future<void>>[];
  var lastSeen = DateTime.now();

  final subscription = page.onResponse.listen((response) {
    final match = _graphql.firstMatch(response.url);
    if (match == null) return;
    lastSeen = DateTime.now();
    // One unreadable response must not take the whole run down: Future.wait
    // rethrows the first failure it sees, and an Error is not an Exception, so
    // the catch inside _collect would not stop it from escaping.
    pending.add(_collect(response, scenario, captured).catchError((Object error) {
      print('  skipped a response: $error');
    }));
  });

  // Never Until.networkIdle here: x.com keeps polling, so "idle" may never come
  // and the wait would burn the whole timeout on every page.
  try {
    await page.goto(scenario.url, wait: Until.domContentLoaded, timeout: _pageTimeout);
  } on Exception catch (error) {
    print('  could not load: $error');
    _failures++;
  }

  for (var scroll = 0; scroll < 4; scroll++) {
    await _settle(() => lastSeen);
    try {
      await page.evaluate('() => window.scrollBy(0, document.body.scrollHeight)');
    } on Exception {
      break; // navigated away or closed; whatever landed is still worth keeping
    }
  }
  await _settle(() => lastSeen);

  await Future.wait(pending).timeout(_drainTimeout, onTimeout: () => <void>[]);
  await subscription.cancel();
  return _write(captured);
}

/// Deletes fixtures this run did not produce, so the directory always describes
/// the current links.json and nothing else. The x-client-transaction-id
/// fixtures come from transaction_id.dart and are kept.
///
/// Skipped when a page failed to load: a run that lost scenarios would delete
/// exactly the fixtures it failed to refresh, and the loss would be silent.
void _prune() {
  if (!_outDir.existsSync()) return;
  if (_failures > 0) {
    print('\n$_failures page(s) failed to load, so nothing was pruned. '
        'Fix those and re-run to clean up stale fixtures.');
    return;
  }

  final stale = _outDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .where((file) => !file.path.startsWith(transactionIdFixtures.path))
      .where((file) => !_writtenThisRun.containsKey(file.path))
      .toList();

  for (final file in stale) {
    print('  removed  ${file.path}');
    file.deleteSync();
  }
  // Deepest first, so a nested directory goes before its parent.
  final dirs = _outDir.listSync(recursive: true).whereType<Directory>().toList()
    ..sort((a, b) => b.path.length.compareTo(a.path.length));
  for (final dir in dirs) {
    if (dir.listSync().isEmpty) dir.deleteSync();
  }
  if (stale.isNotEmpty) print('${stale.length} stale fixture(s) removed');
}

/// Returns as soon as the page has been quiet for [_quiet], or at [_settleCap].
Future<void> _settle(DateTime Function() lastSeen) async {
  final deadline = DateTime.now().add(_settleCap);
  while (DateTime.now().isBefore(deadline)) {
    if (DateTime.now().difference(lastSeen()) > _quiet) return;
    await Future.delayed(Duration(milliseconds: 250));
  }
}

Future<void> _collect(
  Response response,
  Scenario scenario,
  Map<String, Map<String, dynamic>> into,
) async {
  final match = _graphql.firstMatch(response.url)!;
  final uri = Uri.parse(response.url);
  final String body;
  try {
    body = await response.text.timeout(_bodyTimeout);
  } on Exception {
    return; // discarded by Chrome, or never finished; nothing to save
  }

  final operation = match.group(2)!;
  _seen[operation] = (_seen[operation] ?? 0) + 1;
  print('  <- $operation');

  into['$operation|${uri.queryParameters['variables']}'] = {
    'scenario': scenario.description,
    'sourceUrl': scenario.url,
    'operation': operation,
    'host': uri.host,
    'queryId': match.group(1),
    'features': _decode(uri.queryParameters['features']),
    'fieldToggles': _decode(uri.queryParameters['fieldToggles']),
    'variables': _decode(uri.queryParameters['variables']),
    'status': response.status,
    'headers': {
      for (final entry in response.headers.entries)
        if (_keepHeaders.contains(entry.key.toLowerCase())) entry.key.toLowerCase(): entry.value,
    },
    'body': _decode(body) ?? body,
  };
}

dynamic _decode(String? raw) {
  if (raw == null) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    return null;
  }
}

int _write(Map<String, Map<String, dynamic>> captured) {
  var written = 0;
  for (final fixture in captured.values) {
    final text = const JsonEncoder.withIndent(' ').convert(fixture);
    final leak = _secrets.entries.firstWhereOrNull((e) => e.key.hasMatch(text));
    if (leak != null) {
      print('  skipped ${fixture['operation']} — contains a ${leak.value}');
      continue;
    }

    final variables = jsonEncode(fixture['variables']);
    var path = '${_outDir.path}/${fixture['operation']}/${_nameFor(fixture['variables'])}.json';
    final takenBy = _writtenThisRun[path];
    if (takenBy == variables) continue;
    if (takenBy != null) {
      final digest = (variables.hashCode & 0xffffff).toRadixString(16);
      path = path.replaceFirst(RegExp(r'\.json$'), '-$digest.json');
      if (_writtenThisRun.containsKey(path)) continue;
    }
    _writtenThisRun[path] = variables;

    final file = File(path);
    final existed = file.existsSync();
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$text\n');
    print('  ${existed ? 'updated' : 'new    '} $path  [${fixture['status']}]');
    written++;
  }
  return written;
}

/// Names a fixture after what it is about, so the tests read as English.
String _nameFor(dynamic variables) {
  final map = variables is Map ? variables : const {};
  const keys = ['screen_name', 'focalTweetId', 'tweetId', 'rawQuery', 'userId', 'listId'];
  final key = keys.firstWhereOrNull((k) => map[k] != null);
  if (key == null) {
    // A timestamp here would leave one more file behind on every single run.
    final digest = map.isEmpty ? 0 : jsonEncode(map).hashCode & 0xffffff;
    return map.isEmpty ? 'default' : 'vars-${digest.toRadixString(16)}';
  }

  final slug = '${map[key]}'
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  return map['cursor'] != null ? '$slug-page2' : slug;
}
