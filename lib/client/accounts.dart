import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:quax/client/account_selector.dart';
import 'package:quax/database/entities.dart';

final _log = Logger('accounts');

const _accountKeyPrefix = 'account/';
const _secureStorage = FlutterSecureStorage();

// Every request to X picks an account, and reading the secure storage goes through Android each time
Future<List<Account>>? _accounts;

Future<List<Account>> getAccounts() => _accounts ??= _readAccounts().onError((error, stackTrace) {
      _accounts = null;
      return Future.error(error!, stackTrace);
    });

Future<List<Account>> _readAccounts() async {
  final entries = await _secureStorage.readAll();
  return entries.entries
      .where((entry) => entry.key.startsWith(_accountKeyPrefix))
      .map((entry) => Account.fromMap(jsonDecode(entry.value)))
      .toList();
}

/// Decoded auth header for a random account, or null if there is none.
/// Used by one-shot requests (e.g. translation) that don't drive the retry loop.
Future<Map<dynamic, dynamic>?> pickAuthHeader() async {
  final accounts = await getAccounts();
  final account = AccountSelector(accounts).pick(exclude: <String>{});
  if (account == null) {
    return null;
  }
  return json.decode(account.authHeader);
}

/// Saves [account] in place of any account saved before under the same screen name, so logging in again with an
/// account leaves a single, fresh session for it.
Future<void> saveAccount(Account account) async {
  final screenName = account.screenName?.toLowerCase();
  final sameScreenName =
      (await getAccounts()).where((saved) => screenName != null && saved.screenName?.toLowerCase() == screenName);
  for (final saved in sameScreenName) {
    await _secureStorage.delete(key: _accountKey(saved.id));
  }
  await _writeAccount(account);
  _accounts = null;
}

Future<void> copyAccountsToSecureStorage(List<Account> accounts) async {
  try {
    for (final account in accounts) {
      await _writeAccount(account);
    }
  } catch (e, stackTrace) {
    _log.severe('Could not copy the accounts to the secure storage', e, stackTrace);
  }
  _accounts = null;
}

Future<void> deleteAccount(String id) async {
  await _secureStorage.delete(key: _accountKey(id));
  _accounts = null;
}

Future<void> _writeAccount(Account account) =>
    _secureStorage.write(key: _accountKey(account.id), value: jsonEncode(account.toMap()));

// The id of an account is its CSRF token, and the secure storage leaves the names of its keys readable
String _accountKey(String id) => '$_accountKeyPrefix${sha256.convert(utf8.encode(id))}';

@visibleForTesting
void forgetCachedAccounts() => _accounts = null;
