import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await databaseFactory.deleteDatabase(databaseName);
    await Repository().migrate();
  });

  Account account(String id, String screenName) => Account(id: id, authHeader: '{}', screenName: screenName);

  test('Should replace the account saved before when logging in again with it', () async {
    await saveAccount(account('stale-session', 'Alice'));
    await saveAccount(account('other', 'bob'));

    await saveAccount(account('fresh-session', 'alice'));

    final ids = (await getAccounts()).map((a) => a.id);
    expect(ids, unorderedEquals(['fresh-session', 'other']),
        reason: 'The session X ended should be dropped, whatever the case of the screen name, so it is never '
            'picked again, while the other accounts stay');
  });
}
