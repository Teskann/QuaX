import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/utils/paging.dart';

void main() {
  group('CursorPagingController', () {
    group('pagingController.fetchNextPage()', () {
      test('Should pass null for the first page and then the cursor of the page before', () async {
        final seen = <String?>[];
        final controller = CursorPagingController<String, int>((cursor) async {
          seen.add(cursor);
          return (items: [seen.length], nextCursor: 'cursor-${seen.length}');
        });
        addTearDown(controller.dispose);

        controller.pagingController.fetchNextPage();
        await pumpEventQueue();
        controller.pagingController.fetchNextPage();
        await pumpEventQueue();

        expect(seen, [null, 'cursor-1'],
            reason: 'PagingController treats a null page key as the end of the list, so this class '
                'should carry the real API cursor between calls. Losing it loads the first page again and again');
        expect(controller.pagingController.items, [1, 2],
            reason: 'Pages should be added and not replaced, so scrolling keeps the tweets that '
                'are already loaded');
      });

      test('Should stop loading pages when a page returns no next cursor', () async {
        var fetches = 0;
        final controller = CursorPagingController<String, int>((cursor) async {
          fetches++;
          return (items: [1], nextCursor: null);
        });
        addTearDown(controller.dispose);

        controller.pagingController.fetchNextPage();
        await pumpEventQueue();
        controller.pagingController.fetchNextPage();
        await pumpEventQueue();

        expect(fetches, 1,
            reason: 'A null cursor means the end of the feed, so no second call should be made. '
                'Asking again spends one of the limited number of requests for nothing');
        expect(controller.pagingController.value.hasNextPage, isFalse,
            reason: 'The list should stop showing the loading spinner at the bottom');
      });

      test('Should wrap an error so the stack trace reaches the error widget', () async {
        final controller = CursorPagingController<String, int>((cursor) async {
          throw StateError('boom');
        });
        addTearDown(controller.dispose);

        controller.pagingController.fetchNextPage();
        await pumpEventQueue();

        final error = pagingErrorOf(controller.pagingController.value.error);
        expect(error, isNotNull,
            reason: 'PagingController keeps only the error and drops the stack trace, '
                'so fetchPage should wrap both itself');
        expect(error!.error, isStateError,
            reason: 'The original error should be kept inside the wrapper, so the error widget '
                'can tell a rate limit from a broken account and show the right message');
        expect(error.stackTrace, isNotNull,
            reason: 'The error widgets show the stack trace, so it should survive. Without it a '
                'crash report is useless');
      });
    });

    group('replaceFirstPage()', () {
      test('Should swap the items without going back to the loading spinner', () async {
        final controller =
            CursorPagingController<String, int>((cursor) async => (items: [1], nextCursor: 'next'));
        addTearDown(controller.dispose);

        controller.pagingController.fetchNextPage();
        await pumpEventQueue();

        controller.replaceFirstPage([9, 8], 'refreshed');

        expect(controller.pagingController.items, [9, 8],
            reason: 'Pull to refresh should keep the list on screen and only swap its items. '
                'PagingController.refresh would clear it and show a spinner instead');
        expect(controller.pagingController.value.hasNextPage, isTrue,
            reason: 'A new cursor was given, so scrolling down should still be able to load more');
      });
    });

    group('setError()', () {
      test('Should show the error while keeping the items already loaded', () async {
        final controller = CursorPagingController<String, int>(
            (cursor) async => (items: [1, 2], nextCursor: 'next'));
        addTearDown(controller.dispose);

        controller.pagingController.fetchNextPage();
        await pumpEventQueue();
        controller.setError(StateError('refresh failed'), StackTrace.current);

        expect(controller.pagingController.items, [1, 2],
            reason: 'A refresh that fails should leave the tweets the user is reading in place');
        expect(pagingErrorOf(controller.pagingController.value.error), isNotNull,
            reason: 'The error should still be shown, otherwise a failed refresh looks like it '
                'worked');
      });
    });
  });

  group('pagingErrorOf()', () {
    test('Should return null when the error is not a PagingError', () {
      expect(pagingErrorOf(StateError('raw')), isNull,
          reason: 'The paging package can store errors the app never wrapped, so this should give '
              'null and let the error widgets keep working instead of crashing on a cast');
    });
  });
}
