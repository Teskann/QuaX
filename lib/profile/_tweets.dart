import 'package:flutter/material.dart';

import 'package:quax/client/client.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/utils/paging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';

class ProfileTweets extends StatefulWidget {
  final UserWithExtra user;
  final String type;
  final bool includeReplies;
  final List<String> pinnedTweets;
  final BasePrefService pref;

  const ProfileTweets(
      {super.key,
      required this.user,
      required this.type,
      required this.includeReplies,
      required this.pinnedTweets,
      required this.pref});

  @override
  State<ProfileTweets> createState() => _ProfileTweetsState();
}

class _ProfileTweetsState extends State<ProfileTweets> with AutomaticKeepAliveClientMixin<ProfileTweets> {
  late final CursorPagingController<String, TweetChain> _paging;
  PagingController<int, TweetChain> get _pagingController => _paging.pagingController;

  static const int pageSize = 20;
  int loadTweetsCounter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _paging = CursorPagingController<String, TweetChain>(_fetchPage);
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  void incrementLoadTweetsCounter() {
    ++loadTweetsCounter;
  }

  int getLoadTweetsCounter() {
    return loadTweetsCounter;
  }

  Future<CursorPage<String, TweetChain>> _fetchPage(String? cursor) async {
    var result = await Twitter.getTweets(
      widget.user.idStr!,
      widget.type,
      widget.pinnedTweets,
      cursor: cursor,
      count: pageSize,
      includeReplies: widget.includeReplies,
      getTweetsCounter: getLoadTweetsCounter,
      incrementTweetsCounter: incrementLoadTweetsCounter,
    );

    // Stop when the cursor doesn't advance (or is gone), keeping the chains.
    final next = result.cursorBottom;
    return (items: result.chains, nextCursor: next == cursor ? null : next);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Consumer<TweetContextState>(builder: (context, model, child) {
      if (model.hideSensitive && (widget.user.possiblySensitive ?? false)) {
        return EmojiErrorWidget(
          emoji: '🍆🙈🍆',
          message: L10n.current.possibly_sensitive,
          errorMessage: L10n.current.possibly_sensitive_profile,
          onRetry: () async => model.setHideSensitive(false),
          retryText: L10n.current.yes_please,
        );
      }

      return RefreshIndicator(
        onRefresh: () async => _pagingController.refresh(),
        child: PagingListener<int, TweetChain>(
          controller: _pagingController,
          builder: (context, state, fetchNextPage) => PagedListView<int, TweetChain>(
            padding: EdgeInsets.zero,
            state: state,
            fetchNextPage: fetchNextPage,
            addAutomaticKeepAlives: false,
            builderDelegate: PagedChildBuilderDelegate(
              itemBuilder: (context, chain, index) {
                return TweetConversation(
                    id: chain.id, tweets: chain.tweets, username: widget.user.screenName!, isPinned: chain.isPinned);
              },
              firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
                error: pagingErrorOf(state)?.error,
                stackTrace: pagingErrorOf(state)?.stackTrace,
                prefix: L10n.of(context).unable_to_load_the_tweets,
                onRetry: fetchNextPage,
              ),
              newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
                error: pagingErrorOf(state)?.error,
                stackTrace: pagingErrorOf(state)?.stackTrace,
                prefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
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
        ),
      );
    });
  }
}
