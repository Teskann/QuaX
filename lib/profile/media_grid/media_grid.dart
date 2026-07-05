import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/media_grid/gif_playback_gate.dart';
import 'package:quax/profile/media_grid/media_grid_items/media_grid_item.dart';
import 'package:quax/status.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/paging.dart';
import 'package:visibility_detector/visibility_detector.dart';

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

  final GifPlaybackGate _gifGate = GifPlaybackGate();

  @override
  void dispose() {
    _gifGate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    var columns = PrefService.of(context).get<int>(optionMediaGridColumns) ?? 3;

    return RefreshIndicator(
      onRefresh: () async => widget.controller.refresh(),
      child: PagingListener<int, MediaGridItem>(
        controller: widget.controller,
        builder: (context, state, fetchNextPage) => PagedMasonryGridView<int, MediaGridItem>.count(
          state: state,
          fetchNextPage: fetchNextPage,
          padding: const EdgeInsets.all(2),
          crossAxisCount: columns,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
          addAutomaticKeepAlives: false,
          builderDelegate: PagedChildBuilderDelegate<MediaGridItem>(
            itemBuilder: (context, item, index) => _MediaGridTile(item: item, gifGate: _gifGate),
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
  final GifPlaybackGate gifGate;

  const _MediaGridTile({required this.item, required this.gifGate});

  @override
  State<_MediaGridTile> createState() => _MediaGridTileState();
}

class _MediaGridTileState extends State<_MediaGridTile> {
  bool _showMedia = false;

  @override
  void initState() {
    super.initState();

    var disableAutoload = PrefService.of(context, listen: false).get<bool>(optionMediaDisableAutoload) ?? false;
    if (disableAutoload) {
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
        child: item is GifGridItem
            ? _GifGridCell(item: item, gate: widget.gifGate)
            : item.toWidget(context),
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

/// A grid GIF cell that animates only while the shared [GifPlaybackGate] grants
/// it one of the limited playback slots; otherwise it shows a static thumbnail.
class _GifGridCell extends StatefulWidget {
  final GifGridItem item;
  final GifPlaybackGate gate;

  const _GifGridCell({required this.item, required this.gate});

  @override
  State<_GifGridCell> createState() => _GifGridCellState();
}

class _GifGridCellState extends State<_GifGridCell> {
  final Key _visibilityKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    widget.gate.addListener(_onGrantsChanged);
  }

  void _onGrantsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.gate.removeListener(_onGrantsChanged);
    widget.gate.forget(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: (info) => widget.gate.report(this, info.visibleFraction),
      child: widget.gate.isGranted(this)
          ? widget.item.toWidget(context)
          : ExtendedImage.network(widget.item.thumbnailUrl, cache: true, fit: BoxFit.cover),
    );
  }
}
