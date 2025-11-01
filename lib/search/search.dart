import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/search/search_model.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/tweet.dart';
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

  late TabController _tabController;
  late final SearchTweetsModel _topTweetsModel;
  late final SearchTweetsModel _latestTweetsModel;
  late final SearchUsersModel _searchUsersModel;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);

    _topTweetsModel = SearchTweetsModel();
    _latestTweetsModel = SearchTweetsModel();
    _searchUsersModel = SearchUsersModel();

    //_bothControllers = CombinedChangeNotifier(_tabController, _queryController);

    if (widget.focusInputOnOpen) {
      _focusNode.requestFocus();
    }

    _queryController.text = widget.query ?? '';

    // TODO: Focussing makes the selection go to the start?!
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
            Tab(
              icon: Icon(Icons.trending_up),
            ),
            Tab(
              icon: Icon(Icons.access_time_outlined),
            ),
            Tab(
              icon: Icon(Icons.person_search),
            ),
          ],
          labelColor: Theme.of(context).appBarTheme.foregroundColor,
          indicatorColor: Theme.of(context).appBarTheme.foregroundColor,
        ),
      ),
      body: Column(
        children: [
          MultiProvider(
            providers: [
              ChangeNotifierProvider<TweetContextState>(
                  create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive))),
              ChangeNotifierProvider<VideoContextState>(
                  create: (_) => VideoContextState(prefs.get(optionMediaDefaultMute))),
            ],
            child: Expanded(
                child: TabBarView(controller: _tabController, children: [
              TweetSearchResultList<SearchTweetsModel, TweetWithCard>(
                  queryController: _queryController,
                  store: _topTweetsModel,
                  searchFunction: (q) => _topTweetsModel.searchTweets(q, "Top"),
                  itemBuilder: (context, item) {
                    return TweetTile(tweet: item, clickable: true);
                  }),
              TweetSearchResultList<SearchTweetsModel, TweetWithCard>(
                  queryController: _queryController,
                  store: _latestTweetsModel,
                  searchFunction: (q) => _latestTweetsModel.searchTweets(q, "Latest"),
                  itemBuilder: (context, item) {
                    return TweetTile(tweet: item, clickable: true);
                  }),
              TweetSearchResultList<SearchUsersModel, UserWithExtra>(
                  queryController: _queryController,
                  store: _searchUsersModel,
                  searchFunction: (q) => _searchUsersModel.searchUsers(q, context),
                  itemBuilder: (context, user) {
                    return UserTile(user: UserSubscription.fromUser(user));
                  }),
            ])),
          )
        ],
      ),
    );
  }
}

typedef ItemWidgetBuilder<T> = Widget Function(BuildContext context, T item);

class TweetSearchResultList<S extends Store<List<T>>, T> extends StatefulWidget {
  final TextEditingController queryController;
  final S store;
  final Future<void> Function(String query) searchFunction;
  final ItemWidgetBuilder<T> itemBuilder;

  const TweetSearchResultList(
      {super.key,
      required this.queryController,
      required this.store,
      required this.searchFunction,
      required this.itemBuilder});

  @override
  State<TweetSearchResultList<S, T>> createState() => _TweetSearchResultListState<S, T>();
}

class _TweetSearchResultListState<S extends Store<List<T>>, T> extends State<TweetSearchResultList<S, T>> {
  Timer? _debounce;
  String? _previousQuery = '';

  @override
  void initState() {
    super.initState();

    widget.queryController.addListener(() {
      var query = widget.queryController.text;
      if (query == _previousQuery) {
        return;
      }

      // If the current query is different from the last render's query, search
      if (_debounce?.isActive ?? false) {
        _debounce?.cancel();
      }

      // Debounce the search, so we don't make a request per keystroke
      _debounce = Timer(const Duration(milliseconds: 750), () async {
        fetchResults();
      });
    });

    fetchResults();
  }

  void fetchResults() {
    if (mounted) {
      var query = widget.queryController.text;
      _previousQuery = query;
      widget.searchFunction(query);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<S, List<T>>.transition(
      store: widget.store,
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (_, error) => FullPageErrorWidget(
        error: error,
        stackTrace: null,
        prefix: L10n.of(context).unable_to_load_the_search_results,
        onRetry: () => fetchResults(),
      ),
      onState: (_, items) {
        if (items.isEmpty) {
          return Center(child: Text(L10n.of(context).no_results));
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            return widget.itemBuilder(context, items[index]);
          },
        );
      },
    );
  }
}
