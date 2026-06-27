import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:quax/status.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/paging.dart';

class MediaGrid extends StatefulWidget {
  final PagingController<int, MediaGridItem> controller;
  final String firstPageErrorPrefix;
  final String newPageErrorPrefix;
  final String emptyMessage;

  const MediaGrid({
    super.key,
    required this.controller,
    required this.firstPageErrorPrefix,
    required this.newPageErrorPrefix,
    required this.emptyMessage,
  });

  @override
  State<MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends State<MediaGrid> with AutomaticKeepAliveClientMixin<MediaGrid> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async => widget.controller.refresh(),
      child: PagingListener<int, MediaGridItem>(
        controller: widget.controller,
        builder: (context, state, fetchNextPage) => PagedMasonryGridView<int, MediaGridItem>.count(
          state: state,
          fetchNextPage: fetchNextPage,
          padding: const EdgeInsets.all(2),
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          addAutomaticKeepAlives: false,
          builderDelegate: PagedChildBuilderDelegate<MediaGridItem>(
            itemBuilder: (context, item, index) => _MediaGridTile(item: item),
            firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: widget.firstPageErrorPrefix,
              onRetry: fetchNextPage,
            ),
            newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: widget.newPageErrorPrefix,
              onRetry: fetchNextPage,
            ),
            noItemsFoundIndicatorBuilder: (context) => Center(child: Text(widget.emptyMessage)),
          ),
        ),
      ),
    );
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
