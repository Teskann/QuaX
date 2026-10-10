import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/home/x_account_model.dart';

import 'x_pump.dart';

void main() {
  group('XAccountModel', () {
    test('Should be loading until the accounts are looked up', () {
      expect(fakeAccountModel().state.loaded, isFalse, reason: 'Nothing was asked yet');
    });

    test('Should describe the first account with its profile', () async {
      final model = fakeAccountModel(accounts: [fakeAccount('jane'), fakeAccount('john')]);

      await model.loadOnce();

      final account = model.state.account!;
      expect(account.screenName, 'jane', reason: 'The first account is the current one');
      expect(account.name, 'Jane Doe', reason: 'The name comes from the profile');
      expect(account.following, 69, reason: 'The following count comes from the profile');
      expect(account.followers, 8, reason: 'The followers count comes from the profile');
    });

    test('Should know there is no account', () async {
      final model = fakeAccountModel();

      await model.loadOnce();

      expect(model.state.loaded, isTrue, reason: 'The lookup is over');
      expect(model.state.account, isNull, reason: 'There is no account');
    });

    test('Should ignore accounts without a screen name', () async {
      final model = fakeAccountModel(accounts: [Account(id: '1', authHeader: '{}', screenName: null)]);

      await model.loadOnce();

      expect(model.state.account, isNull, reason: 'Without a screen name there is no profile to look up');
    });

    test('Should keep the account when its profile cannot be loaded', () async {
      final model = XAccountModel(accounts: () async => [fakeAccount('jane')], profile: (_) async => throw 'offline');

      await model.loadOnce();

      expect(model.state.account!.screenName, 'jane', reason: 'The handle is known without the network');
      expect(model.state.account!.name, isNull, reason: 'The name needs the profile');
    });

    test('Should look the profile up once however many widgets ask', () async {
      var lookups = 0;
      final model = XAccountModel(
          accounts: () async => [fakeAccount('jane')],
          profile: (_) async {
            lookups++;
            return fakeUser();
          });

      await Future.wait([model.loadOnce(), model.loadOnce()]);
      await model.loadOnce();

      expect(lookups, 1, reason: 'The profile should not be requested again on every rebuild');
    });
  });
}
