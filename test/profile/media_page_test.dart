import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';

void main() {
  group('Media grid paging', () {
    test('Should stop on an empty page even when X hands a fresh cursor', () {
      final page = mediaPageFromStatus(TweetStatus(chains: [], cursorBottom: 'fresh', cursorTop: null), 'previous');

      expect(page.nextCursor, isNull,
          reason: 'X answers the page after the last one with no post and a new cursor, which would be asked forever');
    });

    test('Should stop when the cursor does not advance', () {
      final page = mediaPageFromStatus(TweetStatus(chains: [], cursorBottom: 'same', cursorTop: null), 'same');

      expect(page.nextCursor, isNull, reason: 'The same cursor would load the same page again');
    });
  });
}
