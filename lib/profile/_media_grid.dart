import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/status.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';

class ProfileMediaGrid extends StatefulWidget {
  final UserWithExtra user;
  final BasePrefService pref;

  const ProfileMediaGrid({super.key, required this.user, required this.pref});

  @override
  State<ProfileMediaGrid> createState() => _ProfileMediaGridState();
}

class _ProfileMediaGridState extends State<ProfileMediaGrid> with AutomaticKeepAliveClientMixin<ProfileMediaGrid> {
  late PagingController<String?, MediaGridItem> _pagingController;

  static const int pageSize = 20;
  int loadTweetsCounter = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController(firstPageKey: null);
    _pagingController.addPageRequestListener(_loadTweets);
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }

  void incrementLoadTweetsCounter() {
    ++loadTweetsCounter;
  }

  int getLoadTweetsCounter() {
    return loadTweetsCounter;
  }

  Future<void> _loadTweets(String? cursor) async {
    try {
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

      if (!mounted) {
        return;
      }

      if (result.cursorBottom == _pagingController.nextPageKey) {
        _pagingController.appendLastPage([]);
      } else {
        _pagingController.appendPage(mediaItemsFromChains(result.chains), result.cursorBottom);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        _pagingController.error = [e, stackTrace];
      }
    }
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
        child: PagedMasonryGridView<String?, MediaGridItem>.count(
          pagingController: _pagingController,
          padding: const EdgeInsets.all(2),
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          addAutomaticKeepAlives: false,
          builderDelegate: PagedChildBuilderDelegate<MediaGridItem>(
            itemBuilder: (context, item, index) => _MediaGridTile(item: item),
            firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: _pagingController.error[0],
              stackTrace: _pagingController.error[1],
              prefix: L10n.of(context).unable_to_load_the_tweets,
              onRetry: () => _loadTweets(_pagingController.firstPageKey),
            ),
            newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: _pagingController.error[0],
              stackTrace: _pagingController.error[1],
              prefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
              onRetry: () => _loadTweets(_pagingController.nextPageKey),
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
    });
  }
}

class _MediaGridTile extends StatefulWidget {
  final MediaGridItem item;

  const _MediaGridTile({required this.item});

  @override
  State<_MediaGridTile> createState() => _MediaGridTileState();
}

class _MediaGridTileState extends State<_MediaGridTile> {
  bool _showMedia = false;

  @override
  void initState() {
    super.initState();

    var mediaSize = PrefService.of(context, listen: false).get(optionMediaSize);
    if (mediaSize == 'disabled') {
      cachedImageExists(widget.item.thumbnailUrl).then((value) {
        if (mounted) {
          setState(() {
            _showMedia = value;
          });
        }
      });
    } else {
      _showMedia = true;
    }
  }

  String _getMediaTypeLabel(MediaGridItem item) {
    return switch (item) {
      GifGridItem() => 'GIF',
      PhotoGridItem() => 'photo',
      VideoGridItem() => 'video',
    };
  }

  void _openTweet() {
    Navigator.pushNamed(
      context,
      routeStatus,
      arguments: StatusScreenArguments(
        id: widget.item.tweetId,
        username: widget.item.username,
        tweetOpened: true,
        initialMediaIndex: widget.item.mediaIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    Widget body;
    if (_showMedia) {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openTweet,
        child: item.toWidget(context),
      );
    } else {
      body = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showMedia = true),
        child: Container(
          color: Colors.black26,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(
            L10n.of(context).tap_to_show_getMediaType_item_type(_getMediaTypeLabel(item)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return AspectRatio(
      aspectRatio: item.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: body,
      ),
    );
  }
}
