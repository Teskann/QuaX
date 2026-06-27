import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/media_grid/media_grid.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/paging.dart';

class ProfileMediaGrid extends StatefulWidget {
  final UserWithExtra user;
  final BasePrefService pref;

  const ProfileMediaGrid({super.key, required this.user, required this.pref});

  @override
  State<ProfileMediaGrid> createState() => _ProfileMediaGridState();
}

class _ProfileMediaGridState extends State<ProfileMediaGrid> {
  late final CursorPagingController<String, MediaGridItem> _paging;

  static const int pageSize = 20;
  int loadTweetsCounter = 0;

  @override
  void initState() {
    super.initState();
    _paging = CursorPagingController<String, MediaGridItem>(_fetchPage);
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

  Future<CursorPage<String, MediaGridItem>> _fetchPage(String? cursor) async {
    var result = await Twitter.getTweets(
      widget.user.idStr!,
      'media',
      const [],
      cursor: cursor,
      count: pageSize,
      includeReplies: false,
      getTweetsCounter: getLoadTweetsCounter,
      incrementTweetsCounter: incrementLoadTweetsCounter,
    );

    return mediaPageFromStatus(result, cursor);
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

      return MediaGrid(
        controller: _paging.pagingController,
        firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets,
        newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
        emptyMessage: L10n.of(context).could_not_find_any_tweets_by_this_user,
      );
    });
  }
}
