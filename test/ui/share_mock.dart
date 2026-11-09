import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// Catches what the app shares during the test, instead of opening the share sheet.
List<String?> recordShares() {
  final shared = <String?>[];
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(_shareChannel, (call) async {
    shared.add((call.arguments as Map)['text'] as String?);
    return 'dev.fluttercommunity.plus/share/success';
  });
  addTearDown(() => messenger.setMockMethodCallHandler(_shareChannel, null));
  return shared;
}
