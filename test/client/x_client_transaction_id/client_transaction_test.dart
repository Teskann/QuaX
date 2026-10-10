import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/x_client_transaction_id/client_transaction.dart';
import 'package:quax/client/x_client_transaction_id/client_transaction_id_exception.dart';

const _fixtures = 'test/fixtures/XClientTransactionId';

/// A transaction id is a random byte followed by the payload XORed with it, so
/// two ids for the same request only compare equal once that byte is removed.
List<int> _payloadOf(String transactionId) {
  final bytes = base64.decode(base64.normalize(transactionId));
  return bytes.skip(1).map((byte) => byte ^ bytes.first).toList();
}

/// Replays the files recorded by tool/record/transaction_id.dart.
Future<String> _replay(Uri uri) async {
  final index = jsonDecode(File('$_fixtures/sources.json').readAsStringSync()) as Map<String, dynamic>;
  final name = index['$uri'] as String?;
  if (name == null) {
    throw StateError('The app asked for $uri, which Chrome never downloaded on x.com, so the app no longer '
        'follows the path Chrome takes. Files Chrome downloaded: ${index.keys.join(', ')}. '
        'Fix ClientTransaction._findSignFileUrl / constants.dart to follow them');
  }
  return File('$_fixtures/$name').readAsStringSync();
}

Future<ClientTransaction> _recordedTransaction() async {
  final sources = await ClientTransaction.fetchSources(fetch: _replay);
  return ClientTransaction.fromSources(homePageHtml: sources.homePageHtml, signFileText: sources.signFileText);
}

void main() {
  test('Should raise a ClientTransactionIdException when x.com serves nothing the generator can be built from', () {
    expect(
      () => ClientTransaction.fromSources(homePageHtml: '', signFileText: ''),
      throwsA(isA<ClientTransactionIdException>()),
      reason: 'Bug reports about this failure are recognised by the type of the exception',
    );
  });

  test('Should raise a ClientTransactionIdException when the page no longer has the shape the generator reads', () async {
    final sources = await ClientTransaction.fetchSources(fetch: _replay);
    expect(
      () => ClientTransaction.fromSources(
        homePageHtml: sources.homePageHtml.replaceAll('loading-x-anim', 'gone'),
        signFileText: sources.signFileText,
      ),
      throwsA(isA<ClientTransactionIdException>()),
      reason: 'A RangeError would not carry the marker that starts the fix, although X changed the page',
    );
  });

  test('Should find the sign module by following the recorded x.com files', () async {
    await expectLater(ClientTransaction.fetchSources(fetch: _replay), completes,
        reason: 'The chain page -> entry script -> importer -> sign module no longer leads to the sign module: '
            'read the recorded files and fix ClientTransaction._findSignFileUrl / constants.dart');
  });

  final expected = jsonDecode(File('$_fixtures/expected.json').readAsStringSync()) as Map<String, dynamic>;
  final now = DateTime.fromMillisecondsSinceEpoch(expected['nowMs'] as int);

  for (final testCase in (expected['cases'] as List).cast<Map<String, dynamic>>()) {
    final method = testCase['method'] as String;
    final path = testCase['path'] as String;

    test('Should sign $method $path exactly like x.com does', () async {
      final transaction = await _recordedTransaction();
      expect(
        _payloadOf(transaction.generateTransactionId(method, path, now: now)),
        _payloadOf(testCase['transactionId'] as String),
        reason: 'X rejects a request whose transaction id differs from what its own sign module '
            'computes. If the fixtures were just recorded, X changed its algorithm',
      );
    });
  }
}
