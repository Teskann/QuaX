import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

/// Carries an error together with its stack trace through
/// infinite_scroll_pagination v5.
///
/// The v5 [PagingController] only stores the object thrown by `fetchPage`
/// (the stack trace is dropped) and *rethrows* anything that is not an
/// [Exception]. Our error widgets need both the error and its stack trace, so
/// `fetchPage` callbacks wrap failures in this type.
class PagingError implements Exception {
  final Object error;
  final StackTrace stackTrace;

  const PagingError(this.error, this.stackTrace);
}

/// Reads the [PagingError] stored on a paging [state], or `null` when the
/// stored error isn't one (so error widgets can still degrade gracefully).
PagingError? pagingErrorOf(PagingState state) {
  final error = state.error;
  return error is PagingError ? error : null;
}

/// One fetched page: the items to append and the cursor for the *next* page.
/// A `null` [nextCursor] ends pagination.
typedef CursorPage<C, T> = ({List<T> items, C? nextCursor});

/// A loader for a single page, given the cursor of the page to fetch
/// (`null` for the first page).
typedef CursorPageFetcher<C, T> = Future<CursorPage<C, T>> Function(C? cursor);

/// Bridges the app's cursor-paginated APIs onto infinite_scroll_pagination v5,
/// which drives fetching itself via `getNextPageKey`/`fetchPage`.
///
/// v5 treats a `null` page key as "no more pages", so a nullable API cursor
/// can't double as the page key — we page with monotonic `int` keys and carry
/// the real cursor across fetches here. Each [CursorPageFetcher] returns its
/// items plus the next cursor (`null` ends pagination); errors are wrapped in
/// [PagingError] so the stack trace survives to the error widgets.
class CursorPagingController<C, T> {
  late final PagingController<int, T> pagingController;
  final CursorPageFetcher<C, T> _fetch;
  C? _nextCursor;
  bool _reachedEnd = false;

  CursorPagingController(this._fetch) {
    pagingController = PagingController<int, T>(
      getNextPageKey: (state) {
        final keys = state.keys;
        if (keys == null || keys.isEmpty) return 0;
        return _reachedEnd ? null : keys.last + 1;
      },
      fetchPage: _fetchPage,
    );
  }

  /// The flattened items fetched so far, or `null` before the first page loads.
  List<T>? get items => pagingController.value.items;

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
