import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/ui/errors.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

class StatusScreenArguments {
  final String id;
  final String? username;
  final bool tweetOpened;
  final int initialMediaIndex;
  final TweetWithCard? initialTweet;

  StatusScreenArguments(
      {required this.id,
      required this.username,
      this.tweetOpened = false,
      this.initialMediaIndex = 0,
      this.initialTweet});

  @override
  String toString() {
    return 'StatusScreenArguments{id: $id, username: $username}';
  }
}

class StatusScreen extends StatelessWidget {
  const StatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as StatusScreenArguments;

    return _StatusScreen(
        username: args.username,
        id: args.id,
        tweetOpened: args.tweetOpened,
        initialMediaIndex: args.initialMediaIndex,
        initialTweet: args.initialTweet);
  }
}

class _StatusScreen extends StatefulWidget {
  final String? username;
  final String id;
  final bool tweetOpened;
  final int initialMediaIndex;
  final TweetWithCard? initialTweet;

  const _StatusScreen(
      {required this.username,
      required this.id,
      required this.tweetOpened,
      this.initialMediaIndex = 0,
      this.initialTweet});

  @override
  _StatusScreenState createState() => _StatusScreenState();
}

class _StatusScreenState extends State<_StatusScreen> {
  final _pagingController = PagingController<String?, TweetChain>(firstPageKey: null);
  final _scrollController = AutoScrollController();

  final _seenAlready = <String>{};
  bool _firstLoadStarted = false;

  @override
  void initState() {
    super.initState();

    _pagingController.addPageRequestListener((cursor) {
      _loadTweet(cursor);
    });
    // While the instant preview is shown the PagedListView isn't mounted, so we
    // rebuild to swap it in as soon as the first page (or an error) arrives.
    _pagingController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _pagingController.removeListener(_onControllerChanged);
    _pagingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _showingPreview =>
      widget.initialTweet != null && _pagingController.itemList == null && _pagingController.error == null;

  void _maybeStartFirstLoad() {
    if (_firstLoadStarted) return;
    if (_pagingController.itemList != null || _pagingController.error != null) return;
    _firstLoadStarted = true;
    _loadTweet(_pagingController.firstPageKey);
  }

  void _scrollToFocalTweet(List<TweetChain> chains) {
    // Find the chain holding the opened tweet. Ancestors arrive as earlier
    // chains, so index 0 means there's nothing above it (a top-level tweet,
    // already at the top) — leave the view and highlight alone.
    final index = chains.indexWhere((c) => c.tweets.any((t) => t.idStr == widget.id));
    if (index <= 0) return;
    // Defer one frame: the instant preview is still on screen here; the
    // PagedListView (and its scroll controller) only mounts after the rebuild
    // triggered by the new items. scrollToIndex then handles lazy-list scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) return;
      await _scrollController.scrollToIndex(index, preferPosition: AutoScrollPosition.begin);
      await _scrollController.highlight(index);
    });
  }

  Future _loadTweet(String? cursor) async {
    try {
      var isFirstPage = _pagingController.nextPageKey == null;

      var result = await Twitter.getTweet(widget.id, cursor: cursor);
      if (!mounted) {
        return;
      }

      if (result.cursorBottom != null && result.cursorBottom == _pagingController.nextPageKey) {
        _pagingController.appendLastPage([]);
      } else {
        // Twitter sometimes sends the original replies with all pages, so we need to manually exclude ones that we've already seen
        var chains = result.chains.skipWhile((element) => _seenAlready.contains(element.id)).toList();

        for (var chain in chains) {
          _seenAlready.add(chain.id);
        }

        // No new tweets returned, or the cursor doesn't advance -> stop pagination.
        if (chains.isEmpty || result.cursorBottom == null || result.cursorBottom == _pagingController.nextPageKey) {
          _pagingController.appendLastPage(chains);
        } else {
          _pagingController.appendPage(chains, result.cursorBottom);
        }

        // If we're on the first page, anchor the view on the opened tweet.
        if (isFirstPage) {
          _scrollToFocalTweet(chains);
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        _pagingController.error = [e, stackTrace];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ChangeNotifierProvider<TweetContextState>(
        create: (context) => TweetContextState(PrefService.of(context, listen: false).get(optionTweetsHideSensitive)),
        child: _showingPreview ? _buildPreview(context) : _buildConversation(context),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    _maybeStartFirstLoad();
    var tweet = widget.initialTweet!;
    return ListView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      children: [
        TweetConversation(
          id: tweet.idStr!,
          tweets: [tweet],
          username: null,
          isPinned: false,
          tweetOpened: widget.tweetOpened,
          initialMediaIndex: widget.initialMediaIndex,
        ),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }

  Widget _buildConversation(BuildContext context) {
    return PagedListView<String?, TweetChain>(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      pagingController: _pagingController,
      scrollController: _scrollController,
      addAutomaticKeepAlives: false,
      shrinkWrap: true,
      builderDelegate: PagedChildBuilderDelegate(
        itemBuilder: (context, chain, index) {
          return AutoScrollTag(
            key: ValueKey(chain.id),
            controller: _scrollController,
            index: index,
            highlightColor: Theme.of(context).colorScheme.primary,
            child: TweetConversation(
                id: chain.id,
                tweets: chain.tweets,
                username: null,
                isPinned: chain.isPinned,
                tweetOpened: widget.tweetOpened,
                initialMediaIndex: chain.id == widget.id ? widget.initialMediaIndex : 0),
          );
        },
        firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
          error: _pagingController.error[0],
          stackTrace: _pagingController.error[1],
          prefix: L10n.of(context).unable_to_load_the_tweet,
          onRetry: () => _loadTweet(_pagingController.firstPageKey),
        ),
        newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
          error: _pagingController.error[0],
          stackTrace: _pagingController.error[1],
          prefix: L10n.of(context).unable_to_load_the_next_page_of_replies,
          onRetry: () => _loadTweet(_pagingController.nextPageKey),
        ),
        noItemsFoundIndicatorBuilder: (context) {
          return Center(
            child: Text(
              L10n.of(context).could_not_find_any_tweets_by_this_user,
            ),
          );
        },
      ),
    );
  }
}
