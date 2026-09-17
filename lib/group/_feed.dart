import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_session_cache.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/group/search_query.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
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
                  await openUri(context, "https://github.com/Teskann/QuaX/issues/26");
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

  /// Separator between the chunk index, the number of pages consumed for that
  /// chunk, and the per-chunk search cursor inside a feed cursor. An empty
  /// search cursor means "start this chunk fresh"; an empty page count is 0.
  static const String feedCursorSeparator = '|';

  /// Maximum number of pages a single chunk contributes before the feed moves
  /// on to the next chunk. Bounds how much one tweet-heavy chunk can dominate
  /// the scroll (and the rate-limit budget).
  static const int maxPagesPerChunk = 3;

  /// The index of the chunk the given feed [cursor] points at (`null` for the
  /// very first page, which starts at chunk 0).
  int? _chunkIndexFromCursor(String? cursor) {
    if (cursor == null) return 0;
    return int.tryParse(cursor.split(feedCursorSeparator)[0]);
  }

  /// The number of pages already consumed for the chunk in the given feed
  /// [cursor] (0 for a fresh entry or a malformed cursor).
  int _pageCountFromCursor(String? cursor) {
    if (cursor == null) return 0;
    final parts = cursor.split(feedCursorSeparator);
    if (parts.length < 2) return 0;
    return int.tryParse(parts[1]) ?? 0;
  }

  /// The per-chunk search cursor encoded in the given feed [cursor], or `null`
  /// when the chunk should be loaded fresh from its newest tweets.
  String? _searchCursorFromCursor(String? cursor) {
    if (cursor == null) return null;
    final parts = cursor.split(feedCursorSeparator);
    // Old two-part cursor ("<chunk>|<searchCursor>") kept working.
    if (parts.length == 2) {
      return parts[1].isNotEmpty ? parts[1] : null;
    }
    return parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
  }

  /// Maximum number of consecutive pages of the *same* chunk one page load may
  /// fetch while every result is a tweet the feed has already shown. Advancing
  /// to the next chunk is not capped — only the last chunk pages without a page
  /// cap, so only it could otherwise fetch in a tight loop.
  static const int maxRepeatedChunkPages = 3;

  static const TweetPageResult _emptyPage = (chains: <TweetChain>[], nextCursor: null);

  /// Search for our next "page" of tweets.
  ///
  /// A page is one chunk's live search results (one request), paged from that
  /// chunk's newest tweets downwards via its bottom cursor before the feed moves
  /// on to the next chunk. Cached tweets never enter a page — they only feed the
  /// preview shown while the first page loads — so each page is older than the
  /// page before it.
  Future<TweetPageResult> _listTweets(String? cursorKey) async {
    var cursor = cursorKey;
    var repeatedPages = 0;

    while (repeatedPages < maxRepeatedChunkPages) {
      var chunkIndex = _chunkIndexFromCursor(cursor) ?? 0;
      if (chunkIndex >= widget.chunks.length) return _emptyPage;

      var chunk = widget.chunks[chunkIndex];
      var searchCursor = _searchCursorFromCursor(cursor);
      var result = await _searchChunk(chunk, searchCursor);

      if (searchCursor == null && result.chains.isNotEmpty) {
        await _cacheNewestPage(chunk.hash, result.chains);
      }

      var nextCursor = _nextFeedCursor(chunkIndex, _pageCountFromCursor(cursor) + 1, result, searchCursor);
      var chains = _feedController.retainUnseen(sortChainsNewestFirst(result.chains));
      if (chains.isNotEmpty) {
        await _warnIfFeedContainsUnrelatedPosts(result, chunk.users);
        return (chains: chains, nextCursor: nextCursor);
      }

      // Everything this chunk returned was already on screen, so keep looking
      // rather than handing the list an empty page, which would end pagination.
      if (nextCursor == null) return _emptyPage;
      repeatedPages = _chunkIndexFromCursor(nextCursor) == chunkIndex ? repeatedPages + 1 : 0;
      cursor = nextCursor;
    }

    return _emptyPage;
  }

  Future<TweetStatus> _searchChunk(SubscriptionGroupFeedChunk chunk, String? cursor) {
    var query = buildFeedSearchQuery(chunk.users,
        includeReplies: widget.includeReplies, includeRetweets: widget.includeRetweets);

    return Twitter.searchTweets(query, cursor: cursor);
  }

  /// The feed cursor for the page after a chunk page, or `null` at the end of
  /// the feed. Keeps paging the same chunk while its bottom cursor advances and
  /// the per-chunk page cap allows it. The cap does not apply to the last chunk:
  /// there is nothing left to move on to, so capping it would end the feed early.
  String? _nextFeedCursor(int chunkIndex, int pagesUsed, TweetStatus result, String? searchCursor) {
    var isLastChunk = chunkIndex + 1 >= widget.chunks.length;
    var bottom = result.cursorBottom;
    var chunkHasMore =
        result.chains.isNotEmpty && bottom != null && bottom.isNotEmpty && bottom != searchCursor;

    if (chunkHasMore && (isLastChunk || pagesUsed < maxPagesPerChunk)) {
      return '$chunkIndex$feedCursorSeparator$pagesUsed$feedCursorSeparator$bottom';
    }

    return isLastChunk ? null : '${chunkIndex + 1}$feedCursorSeparator$feedCursorSeparator';
  }

  /// Replaces a chunk's cached tweets with its newest page. The cache only feeds
  /// the preview shown while the first page loads, so one page per chunk is all
  /// it needs — and replacing rather than appending stops the table growing a
  /// row per scrolled page.
  Future<void> _cacheNewestPage(String hash, List<TweetChain> chains) async {
    var repository = await Repository.writable();
    var cursorId = await createCursor(repository);

    await repository.delete(tableFeedGroupChunk, where: 'hash = ?', whereArgs: [hash]);
    await repository.insert(tableFeedGroupChunk, {
      'cursor_id': int.parse(cursorId),
      'hash': hash,
      'response': jsonEncode(chains.map((e) => e.toJson()).toList())
    });
  }

  Future<void> _warnIfFeedContainsUnrelatedPosts(TweetStatus result, List<Subscription> users) async {
    if (!mounted) return;
    if (!feedContainsUnrelatedTweets(result, users)) return;
    if (PrefService.of(context).get(optionDisableWarningsForUnrelatedPostsInFeed)) return;

    await showUnrelatedPostsInFeedWarning();
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
            // Nothing to invalidate: cached tweets only feed the preview, and each
            // chunk's first page rewrites its own cache row.
            onRefresh: () async {},
            firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
            newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
            emptyMessage: L10n.of(context).could_not_find_any_tweets_from_the_last_7_days,
          ),
        ),
      ),
    );
  }
}