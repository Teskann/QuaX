import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/x_client_transaction_id/client_transaction.dart';

const _fixtures = 'test/fixtures/XClientTransactionId';

/// A transaction id is a random byte followed by the payload XORed with it, so
/// two ids for the same request only compare equal once that byte is removed.
List<int> _payloadOf(String transactionId) {
  final bytes = base64.decode(base64.normalize(transactionId));
  return bytes.skip(1).map((byte) => byte ^ bytes.first).toList();
}

void main() {
  final expected = jsonDecode(File('$_fixtures/expected.json').readAsStringSync()) as Map<String, dynamic>;
  final now = DateTime.fromMillisecondsSinceEpoch(expected['nowMs'] as int);
  final transaction = ClientTransaction.fromSources(
    homePageHtml: File('$_fixtures/home.html').readAsStringSync(),
    signFileText: File('$_fixtures/sign.js').readAsStringSync(),
  );

  for (final testCase in (expected['cases'] as List).cast<Map<String, dynamic>>()) {
    final method = testCase['method'] as String;
    final path = testCase['path'] as String;

    test('Should sign $method $path exactly like x.com does', () {
      expect(
        _payloadOf(transaction.generateTransactionId(method, path, now: now)),
        _payloadOf(testCase['transactionId'] as String),
        reason: 'X rejects a request whose transaction id differs from what its own sign module '
            'computes. If the fixtures were just recorded, X changed its algorithm',
      );
    });
  }
}
