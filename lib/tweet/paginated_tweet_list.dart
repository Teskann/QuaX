import 'dart:math';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/feed_refresh_controller.dart';
import 'package:quax/group/feed_scroll_controller.dart';
import 'package:quax/group/unrelated_tweets_warning.dart';
import 'package:quax/release_notes/release_notes.dart';
import 'package:quax/release_notes/release_notes_model.dart';
import 'package:quax/release_notes/release_notes_card.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/tweet/top_item.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/paging.dart';

typedef TweetPageResult = ({List<TweetChain> chains, String? nextCursor});
typedef TweetPageLoader = Future<TweetPageResult> Function(String? cursor);

/// Owns a [CursorPagingController] for cursor-paginated tweet chains, bridging
/// it onto the app's `(chains, nextCursor)` loaders.
///
/// v5 bakes the fetch callback into the controller at construction, yet several
/// feeds create the controller away from the loader. So the loader lives in a
/// rebindable field that [PaginatedTweetList] sets on mount.
class TweetFeedController {
  late final CursorPagingController<String, TweetChain> _paging;
  TweetPageLoader? _loader;

  /// Error of the last soft refresh when it failed while tweets were shown, kept apart from the paging error so that
  /// it is displayed above the tweets and does not block the next pages
  final ValueNotifier<PagingError?> refreshError = ValueNotifier(null);

  /// Error of the part of the last page that could not be loaded while the rest could, shown above the tweets. Set by
  /// loaders made of several requests, like the group feeds
  final ValueNotifier<PagingError?> partialError = ValueNotifier(null);

  /// Whether the loaded pages hold posts from people the user does not follow, shown as a warning above the tweets
  final ValueNotifier<bool> containsUnrelatedTweets = ValueNotifier(false);

  TweetFeedController() {
    _paging = CursorPagingController<String, TweetChain>(_fetch);
  }

  PagingController<int, TweetChain> get controller => _paging.pagingController;

  set loader(TweetPageLoader loader) => _loader = loader;

  bool get hasItems => _paging.items != null;

  List<TweetChain> get items => _paging.items ?? const [];

  /// Shows [chains] without loading anything.
  void seed(List<TweetChain> chains, String? nextCursor) => _paging.replaceFirstPage(chains, nextCursor);

  Future<CursorPage<String, TweetChain>> _fetch(String? cursor) async {
    final result = await _loader!(cursor);
    final next = result.nextCursor;
    return (items: result.chains, nextCursor: _isLastPage(result.chains, next, cursor) ? null : next);
  }

  // Pagination ends on an empty page, a missing/blank cursor, or a cursor that
  // didn't advance (which would otherwise loop forever).
  bool _isLastPage(List<TweetChain> chains, String? next, String? cursor) =>
      chains.isEmpty || next == null || next.isEmpty || next == cursor;

  /// Reloads the first page and replaces the items in place, *without* resetting
  /// to the first-page spinner the way [PagingController.refresh] does. Used by
  /// pull-to-refresh so the existing tweets stay visible under the indicator.
  Future<void> softRefresh() async {
    final hadNextPage = controller.value.hasNextPage;
    // A next page loaded during the refresh would follow the old first page
    controller.value = controller.value.copyWith(hasNextPage: false);
    try {
      final result = await _loader!(null);
      final next = result.nextCursor;
      _paging.replaceFirstPage(result.chains, _isLastPage(result.chains, next, null) ? null : next);
      refreshError.value = null;
    } catch (e, stackTrace) {
      controller.value = controller.value.copyWith(hasNextPage: hadNextPage);
      if (hasItems) {
        refreshError.value = PagingError(e, stackTrace);
      } else {
        _paging.setError(e, stackTrace);
      }
    }
  }

  void dispose() {
    _paging.dispose();
    refreshError.dispose();
    partialError.dispose();
    containsUnrelatedTweets.dispose();
  }
}

/// Shared paginated tweet list used by the For-you feed, the group feed and
/// the tweet search results. Drives a [TweetFeedController]'s v5 controller
/// through the standard `PagedListView` shell with error / empty widgets.
///
/// The controller's lifecycle (creation, disposal, cross-mount caching) stays
/// at the call site — this widget only binds the loader.
class PaginatedTweetList extends StatefulWidget {
  final TweetFeedController feed;
  final TweetPageLoader loadPage;
  final String? username;
  final Future<void> Function()? onRefresh;
  final ErrorPrefix firstPageErrorPrefix;
  final ErrorPrefix newPageErrorPrefix;
  final String emptyMessage;

  /// Reloads the cached tweets from X when the feed opens.
  final bool refreshOnOpen;

  final String? initialTopItem;
  final ValueChanged<String>? onTopItemChanged;

  const PaginatedTweetList({
    super.key,
    required this.feed,
    required this.loadPage,
    required this.username,
    required this.firstPageErrorPrefix,
    required this.newPageErrorPrefix,
    required this.emptyMessage,
    this.onRefresh,
    this.refreshOnOpen = false,
    this.initialTopItem,
    this.onTopItemChanged,
  });

  @override
  State<PaginatedTweetList> createState() => _PaginatedTweetListState();
}

class _PaginatedTweetListState extends State<PaginatedTweetList> {
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  final GlobalKey _aboveKey = GlobalKey();
  final GlobalKey _belowKey = GlobalKey();
  final Key _centerKey = UniqueKey();
  FeedRefreshController? _refreshController;
  FeedScrollController? _scrollController;
  bool _pendingInitialLoad = false;

  /// Index of the tweet shown at the top when the feed opens.
  int _anchor = 0;

  PagingController<int, TweetChain> get _controller => widget.feed.controller;

  @override
  void initState() {
    super.initState();
    widget.feed.loader = widget.loadPage;
    _controller.addListener(_onControllerChanged);
    widget.feed.refreshError.addListener(_onControllerChanged);
    widget.feed.partialError.addListener(_onControllerChanged);
    widget.feed.containsUnrelatedTweets.addListener(_onControllerChanged);
    if (widget.refreshOnOpen && widget.feed.hasItems) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOnOpen());
    }
    _anchor = max(0, widget.feed.items.indexWhere((chain) => chain.id == widget.initialTopItem));
  }

  void _refreshOnOpen() {
    final refreshState = _refreshKey.currentState;
    if (!mounted || refreshState == null) return;
    _pendingInitialLoad = true;
    refreshState.show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scrollController = _readOrNull<FeedScrollController>();
    if (!identical(scrollController, _scrollController)) {
      _scrollController?.unregister(_moveAnchorToTop);
      _scrollController = scrollController?..register(_moveAnchorToTop);
    }
    // Only feeds that support pull-to-refresh expose their refresh to the app-bar button
    if (widget.onRefresh == null) return;
    final refreshController = _readOrNull<FeedRefreshController>();
    if (!identical(refreshController, _refreshController)) {
      _refreshController?.unregister(_showRefresh);
      _refreshController = refreshController?..register(_showRefresh);
    }
  }

  T? _readOrNull<T>() {
    try {
      return context.read<T>();
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _moveAnchorToTop() async {
    if (_anchor == 0) return;
    setState(() => _anchor = 0);
    await WidgetsBinding.instance.endOfFrame;
  }

  bool _onScrollEnd(ScrollEndNotification notification) {
    final viewport = notification.context?.findRenderObject();
    if (notification.depth != 0 || widget.onTopItemChanged == null || viewport is! RenderBox) return false;
    // Waits for the layout of the last scroll
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportTopItem(viewport));
    WidgetsBinding.instance.ensureVisualUpdate();
    return false;
  }

  void _reportTopItem(RenderBox viewport) {
    if (!mounted || !viewport.attached) return;
    final index = topItemIndex(
        viewport: viewport,
        anchor: _anchor,
        above: _aboveKey.currentContext?.findRenderObject(),
        below: _belowKey.currentContext?.findRenderObject());
    final items = widget.feed.items;
    if (index != null && index < items.length) {
      widget.onTopItemChanged?.call(items[index].id);
    }
  }

  @override
  void didUpdateWidget(PaginatedTweetList oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.feed.loader = widget.loadPage;
    if (!identical(oldWidget.feed, widget.feed)) {
      oldWidget.feed.controller.removeListener(_onControllerChanged);
      oldWidget.feed.refreshError.removeListener(_onControllerChanged);
      oldWidget.feed.partialError.removeListener(_onControllerChanged);
      oldWidget.feed.containsUnrelatedTweets.removeListener(_onControllerChanged);
      _controller.addListener(_onControllerChanged);
      widget.feed.refreshError.addListener(_onControllerChanged);
      widget.feed.partialError.addListener(_onControllerChanged);
      widget.feed.containsUnrelatedTweets.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    widget.feed.refreshError.removeListener(_onControllerChanged);
    widget.feed.partialError.removeListener(_onControllerChanged);
    widget.feed.containsUnrelatedTweets.removeListener(_onControllerChanged);
    _refreshController?.unregister(_showRefresh);
    _scrollController?.unregister(_moveAnchorToTop);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {
      if (_anchor >= widget.feed.items.length) _anchor = 0;
    });
  }

  // Drives the same RefreshIndicator the user pulls down, so the app-bar refresh
  // button shows the top spinner and runs the soft refresh identically.
  Future<void> _showRefresh() async {
    await _refreshKey.currentState?.show();
  }

  Widget _buildChain(BuildContext context, TweetChain chain) => TweetConversation(
        id: chain.id,
        tweets: chain.tweets,
        username: widget.username,
        isPinned: chain.isPinned,
      );

  /// Soft refresh used by the pull-to-refresh gesture. Runs the caller's
  /// [onRefresh] side effects, then reloads the first page while keeping the
  /// current tweets visible (the RefreshIndicator shows its own small spinner on
  /// top). Awaited so the spinner stays until done.
  Future<void> _handleRefresh() async {
    final releaseNotes = context.read<ReleaseNotesModel?>();
    await widget.onRefresh?.call();
    if (!mounted) return;
    await widget.feed.softRefresh();
    // A successful refresh hides the release notes
    if (widget.feed.refreshError.value == null) {
      releaseNotes?.hide();
    }
  }

  Widget? _errorAbove(PagingError? error, VoidCallback onRetry) => error == null
      ? null
      : ErrorCard(
          error: error.error, stackTrace: error.stackTrace, prefix: widget.firstPageErrorPrefix, onRetry: onRetry);

  // Search results can't be refreshed, so they don't show the release notes
  Widget _releaseNotes() {
    final model = context.read<ReleaseNotesModel?>();
    if (model == null || widget.onRefresh == null) return const SizedBox.shrink();
    return ScopedBuilder<ReleaseNotesModel, List<ReleaseNote>>(
      store: model,
      onState: (_, releases) =>
          releases.isEmpty ? const SizedBox.shrink() : ReleaseNotesCard(releases: releases, onHide: model.hide),
    );
  }

  Future<void> _onRefreshTriggered() async {
    if (_pendingInitialLoad) {
      _pendingInitialLoad = false;
      await widget.feed.softRefresh();
    } else {
      await _handleRefresh();
    }
    // After a refresh, the anchored tweet may no longer exist
    if (mounted) await _moveAnchorToTop();
  }

  Widget _wrapWithRefresh(Widget child) {
    if (widget.onRefresh == null) return child;
    return RefreshIndicator(key: _refreshKey, onRefresh: _onRefreshTriggered, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final list = PagingListener<int, TweetChain>(
      controller: _controller,
      builder: (context, state, fetchNextPage) => NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: _scrollView(state, fetchNextPage),
      ),
    );

    return _wrapWithRefresh(list);
  }

  Widget _scrollView(PagingState<int, TweetChain> state, NextPageCallback fetchNextPage) {
    final items = state.items ?? const [];
    // The list can shrink before the anchor is reset
    final anchor = _anchor < items.length ? _anchor : 0;
    return CustomScrollView(center: anchor > 0 ? _centerKey : null, slivers: [
      SliverToBoxAdapter(
          child: _errorAbove(widget.feed.refreshError.value ?? widget.feed.partialError.value, _showRefresh)),
      if (widget.feed.containsUnrelatedTweets.value) const SliverToBoxAdapter(child: UnrelatedTweetsWarning()),
      SliverToBoxAdapter(child: _releaseNotes()),
      if (anchor > 0)
        SliverList.builder(
          key: _aboveKey,
          itemCount: anchor,
          itemBuilder: (context, index) => _buildChain(context, items[anchor - 1 - index]),
        ),
      SliverPadding(
        key: _centerKey,
        padding: EdgeInsets.only(top: 4, bottom: MediaQuery.of(context).padding.bottom),
        sliver: _pagedList(
            anchor == 0 ? state : state.copyWith(pages: [items.sublist(anchor)], keys: [state.keys!.last]),
            fetchNextPage),
      ),
    ]);
  }

  Widget _pagedList(PagingState<int, TweetChain> state, NextPageCallback fetchNextPage) =>
      PagedSliverList<int, TweetChain>(
        key: _belowKey,
        state: state,
        fetchNextPage: fetchNextPage,
        addAutomaticKeepAlives: false,
        builderDelegate: PagedChildBuilderDelegate(
          itemBuilder: (context, chain, index) => _buildChain(context, chain),
          firstPageProgressIndicatorBuilder: (context) => const Center(child: CircularProgressIndicator()),
          firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: widget.firstPageErrorPrefix,
            onRetry: fetchNextPage,
          ),
          newPageErrorIndicatorBuilder: (context) => ErrorCard(
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: widget.newPageErrorPrefix,
            onRetry: fetchNextPage,
          ),
          noItemsFoundIndicatorBuilder: (context) => Center(child: Text(widget.emptyMessage)),
        ),
      );
}
