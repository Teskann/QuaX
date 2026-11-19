import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/database/entities.dart';

import 'fresh_accounts.dart';

void main() {
  useFreshAccounts();

  Account account(String id, String? screenName) => Account(id: id, authHeader: '{}', screenName: screenName);

  test('Should replace the account saved before when logging in again with it', () async {
    await saveAccount(account('stale-session', 'Alice'));
    await saveAccount(account('other', 'bob'));

    await saveAccount(account('fresh-session', 'alice'));

    final ids = (await getAccounts()).map((a) => a.id);
    expect(ids, unorderedEquals(['fresh-session', 'other']),
        reason: 'The session X ended should be dropped, whatever the case of the screen name, so it is never '
            'picked again, while the other accounts stay');
  });

  test('Should keep every account saved without a screen name', () async {
    await saveAccount(account('first', null));

    await saveAccount(account('second', null));

    expect((await getAccounts()).map((a) => a.id), unorderedEquals(['first', 'second']),
        reason: 'Accounts saved before screen names were stored have none, and are different accounts');
  });

  test('Should forget an account once deleted', () async {
    await saveAccount(account('kept', 'alice'));
    await saveAccount(account('deleted', 'bob'));
    await getAccounts();

    await deleteAccount('deleted');

    expect((await getAccounts()).map((a) => a.id), ['kept'],
        reason: 'A deleted account should no longer be picked for requests, even though the accounts are cached');
  });

  test('Should not write the id of an account in the name of its key', () async {
    await saveAccount(account('csrf-token', 'alice'));

    final keys = (await const FlutterSecureStorage().readAll()).keys;
    expect(keys.single, isNot(contains('csrf-token')),
        reason: 'The id is the CSRF token of the session, and the secure storage only encrypts the values');
  });
}
