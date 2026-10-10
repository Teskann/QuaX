import 'dart:convert';

import 'package:quax/client/account_selector.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';

Future<List<Account>> getAccounts() async {
  var database = await Repository.readOnly();
  var query = await database.query(tableAccounts);
  return List.from(query).map((e) => Account.fromMap(e)).toList();
}

/// The account saved first, or null if there is none
Future<Account?> firstAccount() async {
  final database = await Repository.readOnly();
  try {
    final rows = await database.query(tableAccounts, orderBy: 'rowid ASC', limit: 1);
    return rows.map(Account.fromMap).firstOrNull;
  } finally {
    await database.close();
  }
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
