// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:puppeteer/puppeteer.dart';
import 'package:quax/client/x_client_transaction_id/client_transaction.dart';

final _outDir = Directory('test/fixtures/XClientTransactionId');

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

Future<void> main() async {
  print('Downloading x.com and its sign module…');
  final (:homePageHtml, :signFileText) = await ClientTransaction.fetchSources();
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  print('Signing ${_requests.length} requests in Chrome…');
  final ids = await _signInChrome(homePageHtml, signFileText, nowMs);

  _outDir.createSync(recursive: true);
  File('${_outDir.path}/home.html').writeAsStringSync(homePageHtml);
  File('${_outDir.path}/sign.js').writeAsStringSync(signFileText);
  File('${_outDir.path}/expected.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'nowMs': nowMs,
    'cases': [
      for (final ((method, path), id) in _requests.indexed.map((e) => (e.$2, ids[e.$1])))
        {'method': method, 'path': path, 'transactionId': id},
    ],
  }));
  print('Written to ${_outDir.path}. Now run:\n  fvm flutter test test/client/x_client_transaction_id/');
}

Future<List<String>> _signInChrome(String html, String signModule, int nowMs) async {
  final browser = await puppeteer.launch();
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
