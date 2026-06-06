import 'package:flutter/material.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/_saved.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/utils/paging.dart';
import 'package:provider/provider.dart';

class ProfileSaved extends StatefulWidget {
  final UserWithExtra user;

  const ProfileSaved({super.key, required this.user});

  @override
  State<ProfileSaved> createState() => _ProfileSavedState();
}

class _ProfileSavedState extends State<ProfileSaved> {
  late final CursorPagingController<int, SavedTweet> _paging;
  PagingController<int, SavedTweet> get _pagingController => _paging.pagingController;

  @override
  void initState() {
    super.initState();
    _paging = CursorPagingController<int, SavedTweet>(_loadTweets);
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  // Saved tweets are a single, non-paginated page (nextCursor always null).
  Future<CursorPage<int, SavedTweet>> _loadTweets(int? cursor) async {
    var model = context.read<SavedTweetModel>();
    await model.listSavedTweets();

    final saved = model.state.where((tweet) => tweet.user == widget.user.idStr).toList();
    return (items: saved, nextCursor: null);
  }

  @override
  Widget build(BuildContext context) {
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

      return PagingListener<int, SavedTweet>(
        controller: _pagingController,
        builder: (context, state, fetchNextPage) => PagedListView<int, SavedTweet>(
          padding: EdgeInsets.zero,
          state: state,
          fetchNextPage: fetchNextPage,
          addAutomaticKeepAlives: false,
          builderDelegate: PagedChildBuilderDelegate(
            itemBuilder: (context, savedTweet, index) => SavedTweetTile(id: savedTweet.id, content: savedTweet.content),
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
                  L10n.of(context).you_have_not_saved_any_tweets_yet,
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
