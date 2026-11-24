import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

/// Carries an error and its stack trace through a [PagingController].
///
/// [PagingController] keeps only the object `fetchPage` throws, not its stack
/// trace, and rethrows anything that is not an [Exception]. Our error widgets
/// need both, so `fetchPage` callbacks wrap failures in this type.
class PagingError implements Exception {
  final Object error;
  final StackTrace stackTrace;

  const PagingError(this.error, this.stackTrace);
}

/// The [error] as a [PagingError], or `null` when it is not one, so error
/// widgets still show something.
PagingError? pagingErrorOf(Object? error) => error is PagingError ? error : null;

/// One fetched page: the items to append and the cursor for the *next* page.
/// A `null` [nextCursor] ends pagination.
typedef CursorPage<C, T> = ({List<T> items, C? nextCursor});

/// A loader for a single page, given the cursor of the page to fetch
/// (`null` for the first page).
typedef CursorPageFetcher<C, T> = Future<CursorPage<C, T>> Function(C? cursor);

/// Bridges the app's cursor-paginated APIs onto infinite_scroll_pagination,
/// which drives fetching itself via `getNextPageKey`/`fetchPage`.
///
/// [PagingController] reads a `null` page key as "no more pages", so a
/// nullable API cursor cannot be the page key. Pages use increasing `int`
/// keys instead, and the real cursor is kept here between fetches. Each
/// [CursorPageFetcher] returns its items and the next cursor (`null` ends
/// pagination). Errors are wrapped in [PagingError] so the error widgets get
/// their stack trace.
class CursorPagingController<C, T> {
  late final PagingController<int, T> pagingController;
  final CursorPageFetcher<C, T> _fetch;
  C? _nextCursor;
  bool _reachedEnd = false;

  CursorPagingController(this._fetch) {
    pagingController = PagingController<int, T>(
      getNextPageKey: (state) {
        if (!state.hasFetched) return 0;
        return _reachedEnd ? null : state.keys.last + 1;
      },
      fetchPage: _fetchPage,
    );
  }

  Future<List<T>> _fetchPage(int pageKey) async {
    if (pageKey == 0) {
      _reachedEnd = false;
      _nextCursor = null;
    }
    try {
      final cursor = pageKey == 0 ? null : _nextCursor;
      final page = await _fetch(cursor);
      _setNextCursor(page.nextCursor);
      return page.items;
    } catch (e, stackTrace) {
      throw PagingError(e, stackTrace);
    }
  }

  void _setNextCursor(C? next) {
    _reachedEnd = next == null;
    _nextCursor = next;
  }

  /// Replaces the first page's items in place and re-seeds the cursor, *without*
  /// resetting to the first-page spinner the way [PagingController.refresh]
  /// does — used by pull-to-refresh so existing items stay visible.
  void replaceFirstPage(List<T> items, C? nextCursor) {
    _setNextCursor(nextCursor);
    pagingController.value = PagingState<int, T>(
      pages: [items],
      keys: const [0],
      hasNextPage: nextCursor != null,
      error: null,
    );
  }

  /// Surfaces an error while keeping any already-loaded items visible.
  void setError(Object error, StackTrace stackTrace) {
    pagingController.value = pagingController.value.copyWith(error: PagingError(error, stackTrace));
  }

  void dispose() => pagingController.dispose();
}
