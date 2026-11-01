import 'package:material_ui/material_ui.dart';

import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_chunk_page.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/subscriptions/refreshed_profiles.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/iterables.dart';
import 'package:quax/utils/paging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class SubscriptionGroupFeed extends StatefulWidget {
  final SubscriptionGroupGet group;
  final List<SubscriptionGroupFeedChunk> chunks;
  final bool includeReplies;
  final bool includeRetweets;

  const SubscriptionGroupFeed(
      {super.key,
      required this.group,
      required this.chunks,
      required this.includeReplies,
      required this.includeRetweets});

  @override
  State<SubscriptionGroupFeed> createState() => _SubscriptionGroupFeedState();
}

class _SubscriptionGroupFeedState extends State<SubscriptionGroupFeed> {
  final TweetFeedController _feedController = TweetFeedController();
  bool _openedFromCache = false;
  String? _position;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _openFromCache();
  }

  Future<void> _openFromCache() async {
    var keepPosition = PrefService.of(context, listen: false).get<bool>(optionKeepFeedOffset) ?? false;
    var repository = await Repository.readOnly();
    var hashes = widget.chunks.map((e) => e.hash);
    var cached = await readCachedChainsForHashes(repository, hashes);
    var cursors = await Future.wait(hashes.map((hash) => readChunkCursor(repository, hash)));
    var position = keepPosition ? await readFeedPosition(repository, widget.group.id) : null;
    if (!mounted) return;
    if (cached.isNotEmpty) {
      _feedController.seed(cached, feedCursorOf(cursors));
    }
    setState(() {
      _openedFromCache = cached.isNotEmpty;
      _position = position;
      _ready = true;
    });
  }

  Future<void> _storePosition(String chainId) async =>
      storeFeedPosition(await Repository.writable(), widget.group.id, chainId);

  @override
  void dispose() {
    _feedController.dispose();
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

  /// Loads the first page when [cursor] is null.
  Future<TweetPageResult> _listTweets(String? cursor) async {
    final subscriptions = context.read<SubscriptionsModel>();
    final repository = await Repository.writable();
    final firstPage = cursor == null;
    final pages =
        await Future.wait(widget.chunks.map((chunk) => loadChunkPage(repository, chunk, firstPage: firstPage)));

    final failed = pages.where((page) => page.failed).toList();
    if (failed.length == pages.length) {
      final error = failed.first.error!;
      Error.throwWithStackTrace(error.error, error.stackTrace);
    }
    _feedController.partialError.value = _partialError(pages);
    await subscriptions.refreshSubscriptions(authorsOf(pages.expand((page) => page.answered)));

    if (!mounted) {
      return (chains: <TweetChain>[], nextCursor: null);
    }

    _updateUnrelatedTweetsWarning(pages.any((page) => page.unrelated), firstPage: firstPage);
    final shown = firstPage ? const <TweetChain>[] : _feedController.items;
    final chains = sortChainsNewestFirst(unseenChains(pages.expand((page) => page.tweets), shown));
    return (chains: chains, nextCursor: feedCursorOf(pages.map((page) => page.cursor)));
  }

  // The warning stays until the next refresh, even when the next pages are fine
  void _updateUnrelatedTweetsWarning(bool foundUnrelatedTweets, {required bool firstPage}) {
    final shown = !firstPage && _feedController.containsUnrelatedTweets.value;
    final disabled = PrefService.of(context).get<bool>(optionDisableWarningsForUnrelatedPostsInFeed) ?? false;
    _feedController.containsUnrelatedTweets.value = shown || (foundUnrelatedTweets && !disabled);
  }

  /// The error to show above the tweets for the chunks that failed. A rate limit tells how much of the feed could load
  PagingError? _partialError(List<ChunkPage> pages) {
    var errors = pages.map((page) => page.error).nonNulls;
    var rateLimit = errors.map((e) => e.error).whereType<RateLimitedException>().firstOrNull;
    if (rateLimit == null) {
      return errors.firstOrNull;
    }
    var total = widget.chunks.fold(0, (sum, chunk) => sum + chunk.users.length);
    var failedSubscriptions = widget.chunks.indexed
        .where((chunk) => pages[chunk.$1].failed)
        .fold(0, (sum, chunk) => sum + chunk.$2.users.length);
    var feedError = FeedRateLimitedException(rateLimit.availableAt, loaded: total - failedSubscriptions, total: total);
    return PagingError(feedError, StackTrace.current);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.chunks.isEmpty) {
      return const Scaffold(body: EmptyGroupFeed());
    }
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final keepPosition = PrefService.of(context).get<bool>(optionKeepFeedOffset) ?? false;

    return Scaffold(
      body: TweetContextScope(
        child: PaginatedTweetList(
          feed: _feedController,
          loadPage: _listTweets,
          username: null,
          refreshOnOpen: _openedFromCache && !keepPosition,
          initialTopItem: _position,
          onTopItemChanged: keepPosition ? _storePosition : null,
          onRefresh: () async {},
          firstPageErrorPrefix: (l10n) => l10n.unable_to_load_the_tweets_for_the_feed,
          newPageErrorPrefix: (l10n) => l10n.unable_to_load_the_next_page_of_tweets,
          emptyMessage: L10n.of(context).could_not_find_any_tweets_from_the_last_7_days,
        ),
      ),
    );
  }
}

/// A feed with nothing to load. Without an account, nothing could load anyway, so the user is invited to add one.
class EmptyGroupFeed extends StatelessWidget {
  final Future<List<Account>> Function() accounts;

  const EmptyGroupFeed({super.key, this.accounts = getAccounts});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: accounts(),
      builder: (context, snapshot) {
        final accounts = snapshot.data;
        if (accounts == null) {
          return const SizedBox.shrink();
        }
        if (accounts.isEmpty) {
          return ListView(children: [
            ErrorCard(
                error: NoAccountAvailableException(),
                stackTrace: null,
                prefix: (l10n) => l10n.unable_to_load_the_tweets_for_the_feed),
          ]);
        }
        return Center(child: Text(L10n.of(context).this_group_contains_no_subscriptions));
      },
    );
  }
}
