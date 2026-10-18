import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_triple/flutter_triple.dart';
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

class SearchArguments {
  final int initialTab;
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
  final int initialTab;
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
  late final SearchUsersModel _searchUsersModel;
  late final SearchFiltersModel _filters;
  final SearchChipsVisibilityModel _chipsVisibility = SearchChipsVisibilityModel();

  Timer? _debounce;
  String? _lastDispatchedQuery;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTab);

    final parsed = SearchQuery.parse(widget.query ?? '', _appLanguage);
    final opened = SearchQuery(parsed.text, widget.filters.merge(parsed.filters));
    final initialQuery = opened.compose(_appLanguage);
    _filters = SearchFiltersModel(opened.filters);
    _topTweets = SearchTweetsPagination(product: 'Top', initialQuery: initialQuery);
    _latestTweets = SearchTweetsPagination(product: 'Latest', initialQuery: initialQuery);
    _mediaResults = SearchMediaPagination(initialQuery: initialQuery);
    _searchUsersModel = SearchUsersModel();

    _queryController.text = opened.text;
    _lastDispatchedQuery = initialQuery;
    _queryController.addListener(_onQueryChanged);

    // TODO: Focussing makes the selection go to the start?!

    // The tweet tabs' first-page requests are fired automatically by their
    // PagedListViews using the initial query above; the user-search Store
    // needs an explicit kick.
    if (initialQuery.isNotEmpty) {
      _searchUsersModel.searchUsers(initialQuery, context);
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
    _searchUsersModel.searchUsers(query, context);
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
          trailing: [_filtersButton(), _followButton()],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.trending_up, semanticLabel: L10n.of(context).search_tab_top)),
            Tab(icon: Icon(Icons.access_time_outlined, semanticLabel: L10n.of(context).search_tab_latest)),
            Tab(icon: Icon(Icons.image, semanticLabel: L10n.of(context).media)),
            Tab(icon: Icon(Icons.person_search, semanticLabel: L10n.of(context).search_tab_people)),
          ],
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
          _filterChips(),
          Expanded(
            child: NotificationListener<UserScrollNotification>(
              onNotification: _followResultsScroll,
              child: TabBarView(
              controller: _tabController,
              children: [
                PaginatedTweetList(
                  feed: _topTweets.feed,
                  loadPage: _topTweets.loadPage,
                  username: null,
                  firstPageErrorPrefix: (l10n) => l10n.unable_to_load_the_search_results,
                  newPageErrorPrefix: (l10n) => l10n.unable_to_load_the_next_page_of_tweets,
                  emptyMessage: L10n.of(context).no_results,
                ),
                PaginatedTweetList(
                  feed: _latestTweets.feed,
                  loadPage: _latestTweets.loadPage,
                  username: null,
                  firstPageErrorPrefix: (l10n) => l10n.unable_to_load_the_search_results,
                  newPageErrorPrefix: (l10n) => l10n.unable_to_load_the_next_page_of_tweets,
                  emptyMessage: L10n.of(context).no_results,
                ),
                SearchMediaGrid(model: _mediaResults),
                _UserSearchResultList(store: _searchUsersModel, onRetry: _dispatchQuery),
              ],
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
