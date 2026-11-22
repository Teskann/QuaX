import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/settings/encrypted_accounts.dart';

// Written by the first version of the format, with the password "correct horse battery"
const _firstVersionBackup = '{"version":1,"kdf":{"name":"argon2id","memory":19456,"iterations":2,"parallelism":1},'
    '"salt":"f0jqeTGFVajt4I+syzK2GA==","nonce":"JIBmhIdQVW4gjSa1",'
    '"cipherText":"4qQCOCQRsdzsYCeTLzlOT3SN7hxSobvWAWHgAXYRVvos9mr5u+/tftg6ZEQwNcCKI4aJZXVwRjC/pw71UH8RjLXxkR1WBhPBq'
    'x9vvOLxkx22hxw=","mac":"T98TEfnHWuBnWfLYU3A88w=="}';

void main() {
  final account = Account(id: 'a1', authHeader: '{"Cookie":"auth_token=secret"}', screenName: 'me');

  Map<String, dynamic> firstVersionBackup() => jsonDecode(_firstVersionBackup);

  test('Should decrypt a backup written by the first version of the format', () async {
    final accounts = await decryptAccounts(EncryptedAccounts.fromJson(firstVersionBackup()), 'correct horse battery');

    expect(accounts.single.authHeader, account.authHeader,
        reason: 'A change to the format or to its settings must not lose the accounts of the backups already made');
  });

  test('Should give the accounts back with the password they were encrypted with', () async {
    final encrypted = await encryptAccounts([account], 'correct horse');

    final accounts = await decryptAccounts(EncryptedAccounts.fromJson(encrypted.toJson()), 'correct horse');

    expect(accounts.single.screenName, 'me', reason: 'The account list in the settings shows this name');
  });

  test('Should refuse a wrong password', () async {
    expect(decryptAccounts(EncryptedAccounts.fromJson(firstVersionBackup()), 'wrong horse'),
        throwsA(isA<WrongPasswordException>()),
        reason: 'The import dialog asks for the password again on this exception');
  });

  test('Should leave nothing of the accounts readable in the backup', () async {
    final backup = jsonEncode((await encryptAccounts([account], 'correct horse')).toJson());

    expect(backup, isNot(contains('secret')), reason: 'Anyone who gets the backup could log in with the session');
    expect(backup, isNot(contains('"me"')), reason: 'The backup should not tell which accounts it holds');
  });

  test('Should not encrypt two backups the same way with the same password', () async {
    final first = (await encryptAccounts([account], 'correct horse')).toJson();
    final second = (await encryptAccounts([account], 'correct horse')).toJson();

    expect(first['salt'], isNot(second['salt']),
        reason: 'A salt reused across backups would let one guess of the password be tried on all of them');
    expect(first['nonce'], isNot(second['nonce']), reason: 'AES-GCM is broken when a key and a nonce are reused');
  });

  group('Should refuse to read a backup', () {
    void expectUnreadable(Map<String, dynamic> Function(Map<String, dynamic> backup) edit, {required String reason}) =>
        expect(() => EncryptedAccounts.fromJson(edit(firstVersionBackup())),
            throwsA(isA<UnreadableAccountsException>()),
            reason: reason);

    test('of a version this one does not know', () {
      expectUnreadable((backup) => backup..['version'] = 2,
          reason: 'A newer format may need another algorithm, and guessing would only fail later');
    });

    test('that asks for too much memory', () {
      expectUnreadable((backup) => backup..['kdf']['memory'] = 1 << 30,
          reason: 'Anyone can hand over a backup, and deriving its key must not crash the app');
    });

    test('that asks for too many passes', () {
      expectUnreadable((backup) => backup..['kdf']['iterations'] = 1000000,
          reason: 'Anyone can hand over a backup, and deriving its key must not freeze the app');
    });

    test('with a field missing', () {
      expectUnreadable((backup) => backup..remove('mac'),
          reason: 'The import dialog shows a clear error instead of waiting forever');
    });

    test('with a nonce of the wrong size', () {
      expectUnreadable((backup) => backup..['nonce'] = base64Encode([1, 2, 3]),
          reason: 'AES-GCM needs a 12-byte nonce, and a shorter one would only fail later');
    });
  });
}
