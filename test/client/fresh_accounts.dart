import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/accounts.dart';

/// Starts each test with an empty secure storage, and no account left in the cache by the test before.
void useFreshAccounts() => setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      forgetCachedAccounts();
    });

// A read-only map makes every write fail, as a broken Android Keystore does
void useBrokenSecureStorage() {
  FlutterSecureStorage.setMockInitialValues(const {});
  forgetCachedAccounts();
}
