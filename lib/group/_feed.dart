import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_session_cache.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
import 'package:quax/utils/iterables.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:quax/utils/urls.dart';

class SubscriptionGroupFeed extends StatefulWidget {
  final SubscriptionGroupGet group;
  final List<SubscriptionGroupFeedChunk> chunks;
  final bool includeReplies;
  final bool includeRetweets;
  // When non-null, the PagingController and scroll offset are stored in the
  // app-scoped FeedSessionCache under this key, so pop+push of the same route
  // restores tweets and scroll position. When null, state is local to this
  // State and disposed normally — used by home-tab usages, which are kept
  // alive by AutomaticKeepAliveClientMixin in the shell.
  final String? cacheKey;
  // Cached tweets to show immediately while the first page loads, seeded by the
  // caller (e.g. the All/Following feed reuses the preview it already read while
  // its subscriptions were loading). Refined to this feed's own chunks once read.
  final List<TweetChain>? initialPreview;

  const SubscriptionGroupFeed(
      {super.key,
      required this.group,
      required this.chunks,
      required this.includeReplies,
      required this.includeRetweets,
      this.cacheKey,
      this.initialPreview});

  @override
  State<SubscriptionGroupFeed> createState() => _SubscriptionGroupFeedState();
}

class _SubscriptionGroupFeedState extends State<SubscriptionGroupFeed> {
  late final TweetFeedController _feedController;
  FeedSessionCache? _cache;
  ScrollController? _innerScrollController;
  bool _scrollRestoreScheduled = false;
  // Cached tweets shown while the first page loads, so opening the feed reveals
  // its previously-loaded content instead of a full-screen spinner.
  List<TweetChain>? _cachedPreview;

  bool get _usesCache => widget.cacheKey != null;

  @override
  void initState() {
    super.initState();
    if (_usesCache) {
      _cache = context.read<FeedSessionCache>();
      _feedController = _cache!.getOrCreateController(widget.cacheKey!);
    } else {
      _feedController = TweetFeedController();
    }
    // Cached (pop/push-restored) controllers already hold their tweets; only a
    // fresh controller needs the preview while it loads the first page.
    _cachedPreview = widget.initialPreview;
    if (!_feedController.hasItems) {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    var repository = await Repository.readOnly();
    var cached = await readCachedChainsForHashes(repository, widget.chunks.map((e) => e.hash));
    if (!mounted) return;
    setState(() => _cachedPreview = cached);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_usesCache) return;
    // Inside NestedScrollView's body, PrimaryScrollController is the inner
    // controller PagedListView attaches to, and the one we need for jumpTo().
    _innerScrollController = PrimaryScrollController.maybeOf(context);
    _maybeRestoreScrollOffset();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_usesCache && notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.hasPixels) {
        _cache!.saveOffset(widget.cacheKey!, metrics.pixels);
      }
    }
    return false;
  }

  void _maybeRestoreScrollOffset() {
    if (_scrollRestoreScheduled) return;
    _scrollRestoreScheduled = true;
    final saved = _cache!.readOffset(widget.cacheKey!);
    if (saved == null || saved <= 0) return;
    _scheduleRestore(saved);
  }

  // The cached items render and lay out across the first few frames, so the
  // ScrollPosition may not be attached yet on the very first post-frame.
  // Keep scheduling post-frame callbacks until the scrollable reports stable
  // dimensions, then jump. Terminates via `mounted` when the widget unmounts.
  void _scheduleRestore(double offset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _innerScrollController;
      if (c == null || !c.hasClients || !c.position.haveDimensions) {
        _scheduleRestore(offset);
        return;
      }
      c.jumpTo(offset.clamp(0.0, c.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    if (!_usesCache) {
      _feedController.dispose();
    }
    // When cached, the FeedSessionCache owns the controller's lifecycle across
    // pop/push; PaginatedTweetList has already detached its own listener.
    super.dispose();
  }

  @override
  void didUpdateWidget(SubscriptionGroupFeed oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.includeReplies != widget.includeReplies ||
        oldWidget.includeRetweets != widget.includeRetweets ||
        !_chunksMatch(oldWidget.chunks, widget.chunks)) {
      _feedController.controller.refresh();
    }
  }

  bool _chunksMatch(List<SubscriptionGroupFeedChunk> a, List<SubscriptionGroupFeedChunk> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].hash != b[i].hash) return false;
    }
    return true;
  }

  Future<String> createCursor(Database repository) async {
    return (await repository.insert(tableFeedGroupCursor, {}, nullColumnHack: 'id')).toString();
  }

  bool feedContainsUnrelatedTweets(TweetStatus tweets, List<Subscription> users) {
    final screenNames = users.map((e) => e.screenName).toSet();
    return tweets.chains.any(
        (chain) => chain.tweets.any((tweet) => tweet.user != null && !screenNames.contains(tweet.user!.screenName)));
  }

  Future<void> showUnrelatedPostsInFeedWarning() async {
    await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("⚠️ ${L10n.of(context).feed_issue_detected}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.of(context).feed_contains_unrelated_tweets),
                SizedBox(height: Theme.of(context).textTheme.bodyMedium!.fontSize! * 2),
                PrefCheckbox(
                  title: Text(
                    L10n.of(context).never_show_again,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  pref: optionDisableWarningsForUnrelatedPostsInFeed,
                )
              ],
            ),
            actions: [
              TextButton(
                child: Text(L10n.of(context).more_info),
                onPressed: () async {
                  await openUri("https://github.com/Teskann/QuaX/issues/26");
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              TextButton(
                child: Text(L10n.of(context).close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  String _buildSearchQuery(List<Subscription> users) {
    var query = '';

    var remainingLength = 512 - query.length;

    for (var user in users) {
      var queryToAdd = '';
      if (user is UserSubscription) {
        queryToAdd = 'from:${user.screenName}';
      } else if (user is SearchSubscription) {
        queryToAdd = '"${user.id}"';
      }

      // If we can add this user to the query and still be less than ~512 characters, do so
      if (query.length + queryToAdd.length < remainingLength) {
        if (query != '' && query.isNotEmpty) {
          query += ' OR ';
        }

        query += queryToAdd;
      } else {
        // Otherwise, add the search future and start a new one
        assert(false, 'should never reach here');
        query = queryToAdd;
      }
    }

    if (!widget.includeReplies) {
      query += ' -filter:replies ';
    }

    if (!widget.includeRetweets) {
      query += ' -filter:retweets ';
    } else {
      query += ' include:nativeretweets ';
    }

    return query;
  }

  /// Search for our next "page" of tweets.
  ///
  /// Here, each page is actually a set of mappings, where the ID of each set is the hash of all the user IDs in that
  /// set. We store this along with the top and bottom pagination cursors, which we use to perform pagination for all
  /// sets at the same time, allowing us to create a feed made up of individual search queries.
  Future<TweetPageResult> _listTweets(String? cursorKey) async {
    List<Future<List<TweetChain>>> futures = [];

    var repository = await Repository.writable();
    var nextCursor = await createCursor(repository);
    bool shouldShowUnrelatedPostsInFeedWarning = false;

    for (var chunk in widget.chunks) {
      var hash = chunk.hash;

      futures.add(Future(() async {
        var tweets = <TweetChain>[];

        String? searchCursor;

        if (cursorKey == null) {
          // We're loading the initial content for the feed screen, so load all the chunks we already have
          var storedChunks = await repository.query(tableFeedGroupChunk,
              where: 'hash = ?', whereArgs: [hash], orderBy: 'created_at DESC');

          // Make sure we load any existing stored tweets from the chunk
          tweets.addAll(chainsFromStoredChunks(storedChunks));

          // Use the latest chunk's top cursor to load any new tweets since the last time we checked
          var latestChunk = storedChunks.firstOrNull;
          if (latestChunk != null) {
            searchCursor = latestChunk['cursor_top'] as String;
          } else {
            // Otherwise we need to perform a fresh load from scratch for this chunk
            searchCursor = null;
          }
        } else {
          // We're currently at the end of our current feed, so load the oldest chunk and use its cursor to load more
          var storedChunks = await repository.query(tableFeedGroupChunk,
              where: 'cursor_id = ? AND hash = ?', whereArgs: [int.parse(cursorKey), hash]);
          if (storedChunks.isNotEmpty) {
            searchCursor = storedChunks.first['cursor_bottom'] as String;
          } else {
            searchCursor = null;
          }
        }

        // Perform our search for the next page of results for this chunk, and add those tweets to our collection
        var query = _buildSearchQuery(chunk.users);
        TweetStatus result =
            await Twitter.searchTweets(query, widget.includeReplies, cursor: searchCursor);
        shouldShowUnrelatedPostsInFeedWarning |= feedContainsUnrelatedTweets(result, chunk.users);

        if (result.chains.isNotEmpty) {
          tweets.addAll(result.chains);

          // Make sure we insert the set of cursors for this latest chunk, ready for the next time we paginate
          await repository.insert(tableFeedGroupChunk, {
            'cursor_id': int.parse(nextCursor),
            'hash': hash,
            'cursor_top': result.cursorTop,
            'cursor_bottom': result.cursorBottom,
            'response': jsonEncode(result.chains.map((e) => e.toJson()).toList())
          });
        }

        return tweets;
      }));
    }

    // Wait for all our searches to complete, then build our list of tweet conversations
    var result = (await Future.wait(futures));
    var threads = sortChainsNewestFirst(result.expand((element) => element).toList());

    if (!mounted) {
      return (chains: <TweetChain>[], nextCursor: null);
    }

    if (shouldShowUnrelatedPostsInFeedWarning &&
        !PrefService.of(context).get(optionDisableWarningsForUnrelatedPostsInFeed)) {
      await showUnrelatedPostsInFeedWarning();
    }

    return (chains: threads, nextCursor: nextCursor);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chunks.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text(L10n.of(context).this_group_contains_no_subscriptions),
        ),
      );
    }

    return Scaffold(
      body: TweetContextScope(
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollNotification,
          child: PaginatedTweetList(
            feed: _feedController,
            loadPage: _listTweets,
            username: null,
            firstPagePreview: _cachedPreview,
            onRefresh: () async {
              var repository = await Repository.writable();
              await repository.delete(tableFeedGroupChunk);
            },
            firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
            newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
            emptyMessage: L10n.of(context).could_not_find_any_tweets_from_the_last_7_days,
          ),
        ),
      ),
    );
  }
}
