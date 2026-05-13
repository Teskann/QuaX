import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/search/search_model.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class SearchArguments {
  final int initialTab;
  final String? query;
  final bool focusInputOnOpen;

  SearchArguments(this.initialTab, {this.query, this.focusInputOnOpen = false});
}

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)!.settings.arguments as SearchArguments;

    return _ResultsScreen(
        initialTab: arguments.initialTab, query: arguments.query, focusInputOnOpen: arguments.focusInputOnOpen);
  }
}

class _ResultsScreen extends StatefulWidget {
  final int initialTab;
  final String? query;
  final bool focusInputOnOpen;

  const _ResultsScreen({required this.initialTab, this.query, this.focusInputOnOpen = false});

  @override
  State<_ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<_ResultsScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final TabController _tabController;
  late final SearchTweetsPagination _topTweets;
  late final SearchTweetsPagination _latestTweets;
  late final SearchUsersModel _searchUsersModel;

  Timer? _debounce;
  String? _lastDispatchedQuery;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

    final initialQuery = widget.query ?? '';
    _topTweets = SearchTweetsPagination(product: 'Top', initialQuery: initialQuery);
    _latestTweets = SearchTweetsPagination(product: 'Latest', initialQuery: initialQuery);
    _searchUsersModel = SearchUsersModel();

    _queryController.text = initialQuery;
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
    super.dispose();
  }

  void _onQueryChanged() {
    if (_queryController.text == _lastDispatchedQuery) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), _dispatchQuery);
  }

  void _dispatchQuery() {
    if (!mounted) return;
    final query = _queryController.text;
    _lastDispatchedQuery = query;
    _topTweets.updateQuery(query);
    _latestTweets.updateQuery(query);
    _searchUsersModel.searchUsers(query, context);
  }

  @override
  Widget build(BuildContext context) {
    var prefs = PrefService.of(context, listen: false);

    return Scaffold(
      // Needed as we're nesting Scaffolds, which causes Flutter to calculate keyboard height incorrectly
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Padding(
          padding: EdgeInsets.fromLTRB(8, 36, 8, 8),
          child: SearchBar(
            controller: _queryController,
            focusNode: _focusNode,
            textInputAction: TextInputAction.search,
            leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
            trailing: [
              FollowButton(user: SearchSubscription(id: _queryController.text, createdAt: DateTime.now())),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.trending_up)),
            Tab(icon: Icon(Icons.access_time_outlined)),
            Tab(icon: Icon(Icons.person_search)),
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
        child: TabBarView(
          controller: _tabController,
          children: [
            PaginatedTweetList(
              pagingController: _topTweets.pagingController,
              loadPage: _topTweets.loadPage,
              username: null,
              firstPageErrorPrefix: L10n.of(context).unable_to_load_the_search_results,
              newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
              emptyMessage: L10n.of(context).no_results,
            ),
            PaginatedTweetList(
              pagingController: _latestTweets.pagingController,
              loadPage: _latestTweets.loadPage,
              username: null,
              firstPageErrorPrefix: L10n.of(context).unable_to_load_the_search_results,
              newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
              emptyMessage: L10n.of(context).no_results,
            ),
            _UserSearchResultList(store: _searchUsersModel, onRetry: _dispatchQuery),
          ],
        ),
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
        prefix: L10n.of(context).unable_to_load_the_search_results,
        onRetry: onRetry,
      ),
      onState: (_, items) {
        if (items.isEmpty) {
          return Center(child: Text(L10n.of(context).no_results));
        }
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            return UserTile(user: UserSubscription.fromUser(items[index]));
          },
        );
      },
    );
  }
}
