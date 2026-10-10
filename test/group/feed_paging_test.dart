import 'package:flutter_test/flutter_test.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_paging.dart';

void main() {
  Map<String, Object?> row(String? cursorBottom) => {
        'cursor_id': 1,
        'hash': 'h',
        'cursor_top': 'top',
        'cursor_bottom': cursorBottom,
        'response': '[]',
      };

  group('decideChunkPaging()', () {
    test('Should skip the chunk when it has no stored row', () {
      expect(decideChunkPaging([]), isA<SkipChunk>(),
          reason: 'A chunk with no row returned no posts, or failed on its first page; searching it again '
              'from the top would append its newest posts a second time');
    });

    test('Should skip the chunk when its row has no bottom cursor', () {
      expect(decideChunkPaging([row(null)]), isA<SkipChunk>(),
          reason: 'Without a bottom cursor there is no place to continue from, so the chunk is exhausted');
    });

    test('Should search from the bottom cursor of the row', () {
      var decision = decideChunkPaging([row('cursor-1')]);

      expect(decision, isA<SearchFromCursor>(), reason: 'A row with a bottom cursor lets the chunk keep paging');
      expect((decision as SearchFromCursor).cursor, 'cursor-1',
          reason: 'The search must continue exactly where the previous page of the chunk stopped');
    });

    test('Should use the first row that has a bottom cursor when there are several', () {
      var decision = decideChunkPaging([row(null), row('cursor-2'), row('cursor-3')]);

      expect((decision as SearchFromCursor).cursor, 'cursor-2',
          reason: 'Rows without a cursor are ignored, and among the others the first one wins');
    });

    test('Should use the first row when several rows have a bottom cursor', () {
      var decision = decideChunkPaging([row('cursor-1'), row('cursor-2')]);

      expect((decision as SearchFromCursor).cursor, 'cursor-1',
          reason: 'The first stored row decides, as it did before the chunks could be skipped');
    });
  });

  group('carryForwardRow()', () {
    test('Should keep the cursor used by the failed search as the bottom cursor', () {
      var carried = carryForwardRow(nextCursorId: 7, hash: 'h', searchCursor: 'cursor-1');

      expect(carried, {
        'cursor_id': 7,
        'hash': 'h',
        'cursor_top': null,
        'cursor_bottom': 'cursor-1',
        'response': '[]',
      }, reason: 'The next page must retry the chunk from the same place, under the new cursor id, with no tweets');
    });

    test('Should carry nothing when the failed search had no cursor', () {
      expect(carryForwardRow(nextCursorId: 7, hash: 'h', searchCursor: null), isNull,
          reason: 'A failed first page has no position to carry, so the chunk stays skipped on later pages');
    });

    test('Should make the carried row lead to a search from the same cursor', () {
      var carried = carryForwardRow(nextCursorId: 7, hash: 'h', searchCursor: 'cursor-1')!;

      expect((decideChunkPaging([carried]) as SearchFromCursor).cursor, 'cursor-1',
          reason: 'The carried row is what the next page reads, so it must resolve to the same cursor');
    });

    test('Should store a response that the first page reads as no tweets', () {
      var carried = carryForwardRow(nextCursorId: 7, hash: 'h', searchCursor: 'cursor-1')!;

      expect(chainsFromStoredChunks([carried]), isEmpty,
          reason: 'Carried rows are also read as cached tweets on the first page, where they must add nothing');
    });
  });
}
