import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/iterables.dart';

void main() {
  group('firstOrNull', () {
    test('Should return null for an empty iterable instead of throwing', () {
      expect(<int>[].firstOrNull, isNull,
          reason: 'The whole point of this extension is to return null where first would throw');
    });

    test('Should return the first item when there is one', () {
      expect([7, 8].firstOrNull, 7,
          reason: 'On a list that is not empty it should behave exactly like first');
    });
  });

  group('firstWhereOrNull()', () {
    test('Should return null when no item matches', () {
      expect([1, 3, 5].firstWhereOrNull((e) => e.isEven), isNull,
          reason: 'No match should give null, where firstWhere would throw a StateError');
    });

    test('Should return the first match, not any match', () {
      expect([1, 2, 4].firstWhereOrNull((e) => e.isEven), 2,
          reason: 'Callers rely on the list order, for example to pick the first media of a '
              'tweet, so the earliest match should win');
    });
  });

  group('groupBy()', () {
    test('Should keep every item under its key, in order', () {
      final grouped = ['aa', 'ab', 'b'].groupBy((e) => e[0]);
      expect(grouped, {
        'a': ['aa', 'ab'],
        'b': ['b'],
      }, reason: 'Grouping should drop no item and should not reorder them inside a group');
    });

    test('Should return an empty map for an empty iterable', () {
      expect(<String>[].groupBy((e) => e.length), isEmpty,
          reason: 'No item should give no key at all, rather than a key holding an empty list');
    });
  });

  group('getRange()', () {
    Iterable<int> asPlainIterable(List<int> values) => values.where((_) => true);

    test('Should include the start index and stop before the end index', () {
      expect(asPlainIterable([1, 2, 3, 4, 5]).getRange(1, 3), [2, 3],
          reason: 'The end index should not be included, same as List.getRange. The values go '
              'through asPlainIterable because List has its own getRange, which hides this '
              'extension, so only a plain Iterable reaches it');
    });

    test('Should go to the end when no end index is given', () {
      expect(asPlainIterable([1, 2, 3]).getRange(1), [2, 3],
          reason: 'The end index is optional here, unlike List.getRange, and leaving it out '
              'should mean "to the end"');
    });

    test('Should return nothing when the start index is past the end', () {
      expect(asPlainIterable([1, 2]).getRange(5), isEmpty,
          reason: 'The file rich_text.dart passes rune positions it has not checked, so a start '
              'index that is too big should give an empty result rather than throw');
    });
  });

  group('sorted()', () {
    test('Should not change the list it was called on', () {
      final source = [3, 1, 2];
      source.sorted((a, b) => a.compareTo(b));
      expect(source, [3, 1, 2],
          reason: 'This method should return a copy. Sorting in place would reorder the caller\'s '
              'list, and tweet chains are sorted while that list is still being read');
    });

    test('Should sort using the given compare function', () {
      expect([3, 1, 2].sorted((a, b) => a.compareTo(b)), [1, 2, 3],
          reason: 'The copy that comes back should be the sorted one, not the original order');
    });
  });

  group('mapWithIndex()', () {
    test('Should pass the position of each item, starting at 0', () {
      expect(['a', 'b'].mapWithIndex((e, i) => '$i$e'), ['0a', '1b'],
          reason: 'The first item should be at 0 and not at 1, and the order should not change');
    });
  });

  group('slices()', () {
    test('Should split the items in order, with a shorter last list', () {
      expect([1, 2, 3, 4, 5].slices(2), [
        [1, 2],
        [3, 4],
        [5],
      ], reason: 'No item is lost, and the order stays');
    });

    test('Should give no list for no items', () {
      expect(<int>[].slices(2), isEmpty, reason: 'There is nothing to split');
    });

    test('Should refuse a size of 0', () {
      expect(() => [1, 2].slices(0), throwsRangeError, reason: 'Lists of 0 items would never end');
      expect(() => <int>[].slices(0), throwsRangeError, reason: 'A size of 0 is wrong, even with no items');
    });
  });
}
