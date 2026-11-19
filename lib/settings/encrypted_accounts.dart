import 'dart:convert';
import 'dart:isolate';

import 'package:cryptography/cryptography.dart';
import 'package:quax/database/entities.dart';

class WrongPasswordException implements Exception {}

class UnreadableAccountsException implements Exception {}

const minimumPasswordLength = 12;

// The memory and passes of RFC 9106's second recommended setting
const _memoryKiB = 64 * 1024;
const _iterations = 3;
const _parallelism = 1;

// A backup is a file anyone can hand over: past these, deriving its key could freeze or crash the app
const _maximumMemoryKiB = 256 * 1024;
const _maximumIterations = 10;
const _maximumParallelism = 8;

final _cipher = AesGcm.with256bits();

/// The accounts of a backup, encrypted with a key derived from a password by Argon2id.
class EncryptedAccounts {
  final int memoryKiB;
  final int iterations;
  final int parallelism;
  final List<int> salt;
  final SecretBox secretBox;

  const EncryptedAccounts(
      {required this.memoryKiB,
      required this.iterations,
      required this.parallelism,
      required this.salt,
      required this.secretBox});

  /// Throws [UnreadableAccountsException] when [json] is not encrypted accounts this version can read.
  factory EncryptedAccounts.fromJson(Map<String, dynamic> json) {
    try {
      final kdf = json['kdf'] as Map<String, dynamic>;
      final accounts = EncryptedAccounts(
          memoryKiB: kdf['memory'] as int,
          iterations: kdf['iterations'] as int,
          parallelism: kdf['parallelism'] as int,
          salt: base64Decode(json['salt'] as String),
          secretBox: SecretBox(base64Decode(json['cipherText'] as String),
              nonce: base64Decode(json['nonce'] as String), mac: Mac(base64Decode(json['mac'] as String))));
      if (json['version'] != 1 || kdf['name'] != 'argon2id' || !accounts._isSafeToDecrypt) {
        throw const FormatException();
      }
      return accounts;
    } catch (_) {
      throw UnreadableAccountsException();
    }
  }

  bool get _isSafeToDecrypt =>
      parallelism >= 1 &&
      parallelism <= _maximumParallelism &&
      memoryKiB >= 8 * parallelism &&
      memoryKiB <= _maximumMemoryKiB &&
      iterations >= 1 &&
      iterations <= _maximumIterations &&
      salt.length >= 16 &&
      secretBox.nonce.length == _cipher.nonceLength &&
      secretBox.mac.bytes.length == 16;

  Map<String, dynamic> toJson() => {
        'version': 1,
        'kdf': {'name': 'argon2id', 'memory': memoryKiB, 'iterations': iterations, 'parallelism': parallelism},
        'salt': base64Encode(salt),
        'nonce': base64Encode(secretBox.nonce),
        'cipherText': base64Encode(secretBox.cipherText),
        'mac': base64Encode(secretBox.mac.bytes),
      };
}

Future<EncryptedAccounts> encryptAccounts(List<Account> accounts, String password) => Isolate.run(() async {
      final salt = SecretKeyData.random(length: 16).bytes;
      final key = await _deriveKey(password, salt, _memoryKiB, _iterations, _parallelism);
      final plainText = utf8.encode(jsonEncode(accounts.map((account) => account.toMap()).toList()));
      return EncryptedAccounts(
          memoryKiB: _memoryKiB,
          iterations: _iterations,
          parallelism: _parallelism,
          salt: salt,
          secretBox: await _cipher.encrypt(plainText, secretKey: key));
    });

/// Throws [WrongPasswordException] when [password] is not the one the accounts were encrypted with, and
/// [UnreadableAccountsException] when they are not accounts once decrypted.
Future<List<Account>> decryptAccounts(EncryptedAccounts encrypted, String password) => Isolate.run(() async {
      final key = await _deriveKey(
          password, encrypted.salt, encrypted.memoryKiB, encrypted.iterations, encrypted.parallelism);
      final List<int> plainText;
      try {
        plainText = await _cipher.decrypt(encrypted.secretBox, secretKey: key);
      } on SecretBoxAuthenticationError {
        throw WrongPasswordException();
      }
      try {
        final accounts = jsonDecode(utf8.decode(plainText)) as List;
        return accounts.map((account) => Account.fromMap(account)).toList();
      } catch (_) {
        throw UnreadableAccountsException();
      }
    });

Future<SecretKey> _deriveKey(String password, List<int> salt, int memoryKiB, int iterations, int parallelism) =>
    Argon2id(memory: memoryKiB, iterations: iterations, parallelism: parallelism, hashLength: 32)
        .deriveKeyFromPassword(password: password, nonce: salt);
