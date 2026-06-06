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
import 'package:quax/utils/paging.dart';
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
  late final CursorPagingController<String, TweetChain> _paging;
  PagingController<int, TweetChain> get _pagingController => _paging.pagingController;
  final _scrollController = AutoScrollController();

  final _seenAlready = <String>{};
  bool _firstLoadStarted = false;

  @override
  void initState() {
    super.initState();

    _paging = CursorPagingController<String, TweetChain>(_fetchPage);
    // While the instant preview is shown the PagedListView isn't mounted, so we
    // rebuild to swap it in as soon as the first page (or an error) arrives.
    _pagingController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _pagingController.removeListener(_onControllerChanged);
    _paging.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _showingPreview {
    final state = _pagingController.value;
    return widget.initialTweet != null && state.items == null && state.error == null;
  }

  void _maybeStartFirstLoad() {
    if (_firstLoadStarted) return;
    final state = _pagingController.value;
    if (state.items != null || state.error != null) return;
    _firstLoadStarted = true;
    // Deferred: we're called from build() and fetchNextPage() mutates the
    // controller synchronously, which would setState() mid-build via our listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pagingController.fetchNextPage();
    });
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

  Future<CursorPage<String, TweetChain>> _fetchPage(String? cursor) async {
    var result = await Twitter.getTweet(widget.id, cursor: cursor);

    // Cursor didn't advance on a later page -> nothing new, drop the page.
    if (cursor != null && result.cursorBottom == cursor) {
      return (items: const <TweetChain>[], nextCursor: null);
    }

    // Twitter sometimes sends the original replies with all pages, so we need to manually exclude ones that we've already seen
    var chains = result.chains.skipWhile((element) => _seenAlready.contains(element.id)).toList();

    for (var chain in chains) {
      _seenAlready.add(chain.id);
    }

    // On the first page (null cursor), anchor the view on the opened tweet.
    if (cursor == null) {
      _scrollToFocalTweet(chains);
    }

    // No new tweets returned, or the cursor doesn't advance -> stop pagination.
    final next = result.cursorBottom;
    final stop = chains.isEmpty || next == null || next == cursor;
    return (items: chains, nextCursor: stop ? null : next);
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
    return PagingListener<int, TweetChain>(
      controller: _pagingController,
      builder: (context, state, fetchNextPage) => PagedListView<int, TweetChain>(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
        state: state,
        fetchNextPage: fetchNextPage,
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
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: L10n.of(context).unable_to_load_the_tweet,
            onRetry: fetchNextPage,
          ),
          newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: L10n.of(context).unable_to_load_the_next_page_of_replies,
            onRetry: fetchNextPage,
          ),
          noItemsFoundIndicatorBuilder: (context) {
            return Center(
              child: Text(
                L10n.of(context).could_not_find_any_tweets_by_this_user,
              ),
            );
          },
        ),
      ),
    );
  }
}
