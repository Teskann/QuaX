import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/community.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/paging.dart';

/// Holds the paging controller and loader for one tab of the tweet search
/// (Top / Latest). The query string is mutable — [updateQuery] swaps it in and
/// refreshes the controller so the next page request hits the new query.
class SearchTweetsPagination {
  final TweetFeedController feed = TweetFeedController();
  final String product;
  String _query;

  SearchTweetsPagination({required this.product, String initialQuery = ''}) : _query = initialQuery;

  Future<TweetPageResult> loadPage(String? cursor) async {
    if (_query.isEmpty) {
      return (chains: <TweetChain>[], nextCursor: null);
    }
    final result = await Twitter.searchTweets(_query, product: product, cursor: cursor);
    return (chains: result.chains, nextCursor: result.cursorBottom);
  }

  void updateQuery(String newQuery) {
    if (newQuery == _query) return;
    _query = newQuery;
    feed.controller.refresh();
  }

  void dispose() {
    feed.dispose();
  }
}

typedef SearchPageFetcher<T> = Future<CursorPage<String, T>> Function(String query, String? cursor);

/// A paged list of search results whose query can change, like the Media tab.
class SearchPagination<T> {
  late final CursorPagingController<String, T> _paging = CursorPagingController(_loadPage);
  final SearchPageFetcher<T> _fetch;
  String _query;

  SearchPagination(this._fetch, {String initialQuery = ''}) : _query = initialQuery;

  PagingController<int, T> get pagingController => _paging.pagingController;

  Future<CursorPage<String, T>> _loadPage(String? cursor) async {
    if (_query.isEmpty) {
      return (items: <T>[], nextCursor: null);
    }
    return _fetch(_query, cursor);
  }

  void updateQuery(String newQuery) {
    if (newQuery == _query) return;
    _query = newQuery;
    _paging.pagingController.refresh();
  }

  void dispose() {
    _paging.dispose();
  }
}

class SearchMediaPagination extends SearchPagination<MediaGridItem> {
  SearchMediaPagination({super.initialQuery}) : super(_loadMedia);

  static Future<CursorPage<String, MediaGridItem>> _loadMedia(String query, String? cursor) async {
    final result = await Twitter.searchTweets(query, product: 'Media', cursor: cursor);
    return mediaPageFromStatus(result, cursor);
  }
}

class SearchCommunitiesPagination extends SearchPagination<Community> {
  SearchCommunitiesPagination({super.initialQuery})
      : super((query, cursor) => Twitter.searchCommunities(query, cursor: cursor));
}

class SearchUsersModel extends Store<List<UserWithExtra>> {
  SearchUsersModel() : super([]);

  Future<void> searchUsers(String query, BuildContext context) async {
    await execute(() async {
      if (query.isEmpty) {
        return [];
      } else {
        return await Twitter.searchUsers(query);
      }
    });
  }
}

class SearchFiltersModel extends Store<SearchFilters> {
  SearchFiltersModel([super.initialState = SearchFilters.none]);

  void set(SearchFilters filters) => update(filters);

  void remove(ActiveFilter filter) => update(state.without(filter));
}

/// Whether the filter chips show above the results: they hide while the results scroll down and come back up with them.
class SearchChipsVisibilityModel extends Store<bool> {
  SearchChipsVisibilityModel() : super(true);

  void follow(ScrollDirection direction) => switch (direction) {
    ScrollDirection.reverse => update(false),
    ScrollDirection.forward => update(true),
    ScrollDirection.idle => null,
  };
}
