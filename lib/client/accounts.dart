import 'dart:convert';

import 'package:quax/client/account_selector.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';

Future<List<Account>> getAccounts() async {
  var database = await Repository.readOnly();
  var query = await database.query(tableAccounts);
  return List.from(query).map((e) => Account.fromMap(e)).toList();
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
  final database = await Repository.writable();
  await database.transaction((transaction) async {
    await transaction.delete(tableAccounts, where: 'lower(screen_name) = lower(?)', whereArgs: [account.screenName]);
    await transaction.insert(tableAccounts, account.toMap());
  });
}
