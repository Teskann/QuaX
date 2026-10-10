import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/x_post_url.dart';

void main() {
  group('xPostUri', () {
    test('Should build the address of the post from its author and id', () {
      expect(xPostUri('jack', '20'), 'https://x.com/jack/status/20', reason: 'The address names the author');
    });

    test('Should fall back to the generic address when the author is unknown', () {
      expect(xPostUri(null, '20'), 'https://x.com/i/status/20', reason: 'X resolves the post from its id alone');
    });
  });
}
