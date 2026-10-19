import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/success_cache.dart';

void main() {
  test('Should compute the value only once when it succeeds', () async {
    var calls = 0;
    final cache = SuccessCache(() async => ++calls);

    await cache();
    await cache();

    expect(calls, 1, reason: 'A value that was computed must be reused, not computed again on every call');
  });

  test('Should share one computation between calls made before it ends', () async {
    var calls = 0;
    final cache = SuccessCache(() async => ++calls);

    await Future.wait([cache(), cache()]);

    expect(calls, 1, reason: 'Parallel requests must not each fetch x.com again');
  });

  test('Should compute again on the next call after a failure', () async {
    var calls = 0;
    final cache = SuccessCache(() async => ++calls == 1 ? throw Exception('503') : calls);

    await expectLater(cache(), throwsException, reason: 'The first failure must still reach the caller');

    expect(await cache(), 2,
        reason: 'A failure must not be kept, otherwise one transient error breaks every request until a restart');
  });
}
