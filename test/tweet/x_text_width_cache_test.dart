import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/x_text_width_cache.dart';

void main() {
  const style = TextStyle(fontSize: 16);

  group('TextWidthCache', () {
    late int measures;
    late TextWidthCache cache;

    TextWidthCache newCache({int capacity = 512}) {
      measures = 0;
      return TextWidthCache(capacity: capacity, measure: (text, style, scaler, direction) {
        measures++;
        return text.length * style.fontSize!;
      });
    }

    setUp(() => cache = newCache());

    test('Should not measure again a text with the same style and scaler', () {
      final first = cache.width('Ada', style, TextScaler.noScaling, TextDirection.ltr);
      final second = cache.width('Ada', style, TextScaler.noScaling, TextDirection.ltr);

      expect(second, first, reason: 'The cached width should be the measured one');
      expect(measures, 1, reason: 'The second layout should hit the cache');
    });

    test('Should measure again when the text, the style or the scaler differ', () {
      cache.width('Ada', style, TextScaler.noScaling, TextDirection.ltr);
      cache.width('Bob', style, TextScaler.noScaling, TextDirection.ltr);
      cache.width('Ada', style.copyWith(fontWeight: FontWeight.bold), TextScaler.noScaling, TextDirection.ltr);
      cache.width('Ada', style, const TextScaler.linear(2), TextDirection.ltr);

      expect(measures, 4, reason: 'Each combination has its own width');
    });

    test('Should drop the least recently used entry when full', () {
      cache = newCache(capacity: 2);
      cache.width('a', style, TextScaler.noScaling, TextDirection.ltr);
      cache.width('b', style, TextScaler.noScaling, TextDirection.ltr);
      cache.width('a', style, TextScaler.noScaling, TextDirection.ltr);
      cache.width('c', style, TextScaler.noScaling, TextDirection.ltr);
      expect(cache.length, 2, reason: 'The cache should stay bounded');

      measures = 0;
      cache.width('a', style, TextScaler.noScaling, TextDirection.ltr);
      expect(measures, 0, reason: 'The recently used entry should have been kept');
      cache.width('b', style, TextScaler.noScaling, TextDirection.ltr);
      expect(measures, 1, reason: 'The least recently used entry should have been dropped');
    });
  });
}
