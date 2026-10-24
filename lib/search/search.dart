import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/community/community_search_results.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/search/search_filter_chips.dart';
import 'package:quax/search/search_filter_labels.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/search/search_filters_button.dart';
import 'package:quax/search/search_filters_screen.dart';
import 'package:quax/search/search_media_grid.dart';
import 'package:quax/search/search_model.dart';
import 'package:quax/search/search_query.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

/// The tabs of the search results, in the order they are shown.
enum SearchTab {
  top(filterable: true),
  latest(filterable: true),
  media(filterable: true),
  // X ignores the filters when it searches accounts
  people(filterable: false),
  // X only searches communities by their name and description
  communities(filterable: false);

  const SearchTab({required this.filterable});

  /// Whether the filters of the search apply to the results of this tab.
  final bool filterable;
}

class SearchArguments {
  final SearchTab initialTab;
  final String? query;
  final SearchFilters filters;
  final bool focusInputOnOpen;

  SearchArguments(this.initialTab, {this.query, this.filters = SearchFilters.none, this.focusInputOnOpen = false});
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as SearchArguments;

    return _ResultsScreen(
        initialTab: arguments.initialTab,
        query: arguments.query,
        filters: arguments.filters,
        focusInputOnOpen: arguments.focusInputOnOpen);
  }
}

class _ResultsScreen extends StatefulWidget {
  final SearchTab initialTab;
  final String? query;
  final SearchFilters filters;
  final bool focusInputOnOpen;

  const _ResultsScreen(
      {required this.initialTab, this.query, this.filters = SearchFilters.none, this.focusInputOnOpen = false});

  @override
  State<_ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<_ResultsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final String _appLanguage = appSearchLanguage();

  late final TabController _tabController;
  late final SearchTweetsPagination _topTweets;
  late final SearchTweetsPagination _latestTweets;
  late final SearchMediaPagination _mediaResults;
  late final SearchCommunitiesPagination _communities;
  late final SearchUsersModel _searchUsersModel;
  late final SearchFiltersModel _filters;
  final SearchChipsVisibilityModel _chipsVisibility = SearchChipsVisibilityModel();

  Timer? _debounce;
  String? _lastDispatchedQuery;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: SearchTab.values.length, vsync: this, initialIndex: widget.initialTab.index);

    final parsed = SearchQuery.parse(widget.query ?? '', _appLanguage);
    final opened = SearchQuery(parsed.text, widget.filters.merge(parsed.filters));
    final initialQuery = opened.compose(_appLanguage);
    _filters = SearchFiltersModel(opened.filters);
    _topTweets = SearchTweetsPagination(product: 'Top', initialQuery: initialQuery);
    _latestTweets = SearchTweetsPagination(product: 'Latest', initialQuery: initialQuery);
    _mediaResults = SearchMediaPagination(initialQuery: initialQuery);
    _communities = SearchCommunitiesPagination(initialQuery: opened.text);
    _searchUsersModel = SearchUsersModel();

    _queryController.text = opened.text;
    _lastDispatchedQuery = initialQuery;
    _queryController.addListener(_onQueryChanged);

    // TODO: Focussing makes the selection go to the start?!

    // The tweet tabs' first-page requests are fired automatically by their
    // PagedListViews using the initial query above; the user-search Store
    // needs an explicit kick.
    if (opened.text.isNotEmpty) {
      _searchUsersModel.searchUsers(opened.text, context);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _topTweets.dispose();
    _latestTweets.dispose();
    _mediaResults.dispose();
    _communities.dispose();
    _filters.destroy();
    _chipsVisibility.destroy();
    super.dispose();
  }

  /// What is sent to X: the bar text, with the operators typed in it, and the filters.
  String _effectiveQuery() {
    final typed = SearchQuery.parse(_queryController.text, _appLanguage);
    return SearchQuery(typed.text, _filters.state.merge(typed.filters)).compose(_appLanguage);
  }

  void _onQueryChanged() {
    if (_effectiveQuery() == _lastDispatchedQuery) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), _dispatchQuery);
  }

  void _dispatchQuery() {
    _debounce?.cancel();
    if (!mounted) return;
    final query = _effectiveQuery();
    if (query == _lastDispatchedQuery) return;
    _lastDispatchedQuery = query;
    _topTweets.updateQuery(query);
    _latestTweets.updateQuery(query);
    _mediaResults.updateQuery(query);
    final words = SearchQuery.parse(_queryController.text, _appLanguage).text;
    _communities.updateQuery(words);
    _searchUsersModel.searchUsers(words, context);
  }

  /// Moves the operators typed in the bar to the filters, so only the words stay in the bar.
  void _moveTypedFilters() {
    final typed = SearchQuery.parse(_queryController.text, _appLanguage);
    if (typed.filters.active.isNotEmpty) {
      _filters.set(_filters.state.merge(typed.filters));
      _queryController.text = typed.text;
    }
    _dispatchQuery();
  }

  Future<void> _openFilters() async {
    _moveTypedFilters();
    final edited = await SearchFiltersScreen.open(context, _filters.state);
    if (edited != null) {
      _filters.set(edited);
      _dispatchQuery();
    }
  }

  void _removeFilter(ActiveFilter filter) {
    _filters.remove(filter);
    _dispatchQuery();
  }

  Widget _filtersButton() {
    return ScopedBuilder<SearchFiltersModel, SearchFilters>(
      store: _filters,
      onState: (_, filters) => SearchFiltersButton(count: filters.active.length, onPressed: _openFilters),
    );
  }

  Widget _followButton() {
    return ValueListenableBuilder(
      valueListenable: _queryController,
      builder: (context, _, _) => ScopedBuilder<SearchFiltersModel, SearchFilters>(
        store: _filters,
        onState: (_, _) => FollowButton(user: SearchSubscription(id: _effectiveQuery(), createdAt: DateTime.now())),
      ),
    );
  }

  /// Shows [child] only on the tabs whose results the filters apply to.
  Widget _whenFilterable(Widget child) => ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) => SearchTab.values[_tabController.index].filterable ? child : const SizedBox.shrink(),
      );

  Widget _filterChips() {
    return ScopedBuilder<SearchFiltersModel, SearchFilters>(
      store: _filters,
      onState: (_, filters) => filters.active.isEmpty
          ? const SizedBox.shrink()
          : ScopedBuilder<SearchChipsVisibilityModel, bool>(
              store: _chipsVisibility,
              onState: (_, visible) => ClipRect(
                child: AnimatedAlign(
                  alignment: Alignment.bottomCenter,
                  heightFactor: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: SearchFilterChips(filters: filters, onRemoved: _removeFilter, onTap: _openFilters),
                ),
              ),
            ),
    );
  }

  bool _followResultsScroll(UserScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _chipsVisibility.follow(notification.direction);
    }
    return false;
  }

  Tab _tab(SearchTab tab) {
    final l10n = L10n.of(context);
    final (icon, label) = switch (tab) {
      SearchTab.top => (Icons.trending_up, l10n.search_tab_top),
      SearchTab.latest => (Icons.access_time_outlined, l10n.search_tab_latest),
      SearchTab.media => (Icons.image, l10n.media),
      SearchTab.people => (Icons.person_search, l10n.search_tab_people),
      SearchTab.communities => (Icons.groups, l10n.search_tab_communities),
    };
    return Tab(icon: Icon(icon, semanticLabel: label));
  }

  Widget _tweets(SearchTweetsPagination pagination) => PaginatedTweetList(
        feed: pagination.feed,
        loadPage: pagination.loadPage,
        username: null,
        firstPageErrorPrefix: (l10n) => l10n.unable_to_load_the_search_results,
        newPageErrorPrefix: (l10n) => l10n.unable_to_load_the_next_page_of_tweets,
        emptyMessage: L10n.of(context).no_results,
      );

  Widget _results(SearchTab tab) => switch (tab) {
        SearchTab.top => _tweets(_topTweets),
        SearchTab.latest => _tweets(_latestTweets),
        SearchTab.media => SearchMediaGrid(model: _mediaResults),
        SearchTab.people => _UserSearchResultList(store: _searchUsersModel, onRetry: _dispatchQuery),
        SearchTab.communities => CommunitySearchResults(model: _communities),
      };

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context, listen: false);

    return Scaffold(
      // Needed as we're nesting Scaffolds, which causes Flutter to calculate keyboard height incorrectly
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: kToolbarHeight + 16,
        titleSpacing: 8,
        title: SearchBar(
          controller: _queryController,
          focusNode: _focusNode,
          textInputAction: TextInputAction.search,
          hintText: L10n.of(context).search,
          onSubmitted: (_) => _moveTypedFilters(),
          leading: IconButton(
              icon: Icon(Icons.arrow_back, semanticLabel: L10n.of(context).back),
              onPressed: () => Navigator.pop(context)),
          trailing: [_whenFilterable(Row(mainAxisSize: MainAxisSize.min, children: [_filtersButton(), _followButton()]))],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: SearchTab.values.map(_tab).toList(),
          labelColor: Theme.of(context).appBarTheme.foregroundColor,
          indicatorColor: Theme.of(context).appBarTheme.foregroundColor,
          dividerColor: Theme.of(context).colorScheme.surfaceBright.withAlpha(150),
        ),
      ),
      body: MultiProvider(
        providers: [
          ChangeNotifierProvider<TweetContextState>(
              create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive))),
          ChangeNotifierProvider<VideoContextState>(
              create: (_) => VideoContextState(prefs.get(optionMediaDefaultMute))),
        ],
        child: Column(children: [
          _whenFilterable(_filterChips()),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _followResultsScroll,
              child: TabBarView(
              controller: _tabController,
              children: SearchTab.values.map(_results).toList(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _UserSearchResultList extends StatelessWidget {
  final SearchUsersModel store;
  final VoidCallback onRetry;

  const _UserSearchResultList({required this.store, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<SearchUsersModel, List<UserWithExtra>>.transition(
      store: store,
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (_, error) => FullPageErrorWidget(
        error: error,
        stackTrace: null,
        prefix: (l10n) => l10n.unable_to_load_the_search_results,
        onRetry: onRetry,
      ),
      onState: (_, items) {
        if (items.isEmpty) {
          return Center(child: Text(L10n.of(context).no_results));
        }
        return ListView.builder(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return UserTile(user: UserSubscription.fromUser(items[index]));
          },
        );
      },
    );
  }
}
