import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory directory;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('quax_first_account');
    await databaseFactoryFfi.setDatabasesPath(directory.path);
    await Repository().migrate();
  });

  tearDown(() async {
    final database = await Repository.writable();
    await database.close();
    await directory.delete(recursive: true).catchError((_) => directory);
  });

  Future<void> save(String id, String screenName) async {
    final database = await Repository.writable();
    await database.insert(tableAccounts, Account(id: id, authHeader: '{}', screenName: screenName).toMap());
    await database.close();
  }

  group('firstAccount', () {
    test('Should return nothing when no account was saved', () async {
      expect(await firstAccount(), isNull, reason: 'There is no account to sign in with');
    });

    test('Should return the only account', () async {
      await save('csrf-1', 'ada');

      final account = await firstAccount();

      expect(account?.screenName, 'ada', reason: 'The only account should be returned');
    });

    test('Should return the account saved first, whatever its id', () async {
      await save('zzz', 'ada');
      await save('aaa', 'grace');
      await save('mmm', 'alan');

      final account = await firstAccount();

      expect(account?.screenName, 'ada', reason: 'The earliest insertion wins, not the smallest id');
    });
  });
}
