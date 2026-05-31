import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/feed_refresh_controller.dart';
import 'package:quax/tweet/cached_tweet_list.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/ui/errors.dart';

typedef TweetPageResult = ({List<TweetChain> chains, String? nextCursor});
typedef TweetPageLoader = Future<TweetPageResult> Function(String? cursor);

/// Shared paginated tweet list used by the For-you feed, the group feed and
/// the tweet search results. Owns the wiring between a [PagingController] and
/// a [TweetPageLoader] callback, plus the standard `PagedListView` shell with
/// error / empty widgets.
///
/// The controller's lifecycle (creation, disposal, cross-mount caching) stays
/// at the call site — this widget only attaches and detaches its page-request
/// listener.
class PaginatedTweetList extends StatefulWidget {
  final PagingController<String?, TweetChain> pagingController;
  final TweetPageLoader loadPage;
  final String? username;
  final Future<void> Function()? onRefresh;
  final String firstPageErrorPrefix;
  final String newPageErrorPrefix;
  final String emptyMessage;
  // Cached tweets shown in place of the first-page spinner while the initial
  // load is in flight, so a feed reveals its cached content instead of a
  // full-screen progress indicator.
  final List<TweetChain>? firstPagePreview;

  const PaginatedTweetList({
    super.key,
    required this.pagingController,
    required this.loadPage,
    required this.username,
    required this.firstPageErrorPrefix,
    required this.newPageErrorPrefix,
    required this.emptyMessage,
    this.onRefresh,
    this.firstPagePreview,
  });

  @override
  State<PaginatedTweetList> createState() => _PaginatedTweetListState();
}

class _PaginatedTweetListState extends State<PaginatedTweetList> {
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();
  FeedRefreshController? _refreshController;
  bool _firstLoadStarted = false;
  bool _pendingInitialLoad = false;

  @override
  void initState() {
    super.initState();
    widget.pagingController.addPageRequestListener(_handlePageRequest);
    // While we show the cached preview the PagedListView isn't mounted, so it
    // can't trigger the first page itself — we rebuild to swap it in once items
    // arrive, so listen for that.
    widget.pagingController.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only feeds that support pull-to-refresh expose their refresh to the
    // app-bar button. Outside a GroupFeedShell there is no controller to bind.
    if (widget.onRefresh == null) return;
    FeedRefreshController? controller;
    try {
      controller = context.read<FeedRefreshController>();
    } on ProviderNotFoundException {
      controller = null;
    }
    if (!identical(controller, _refreshController)) {
      _refreshController?.unregister(_showRefresh);
      _refreshController = controller;
      _refreshController?.register(_showRefresh);
    }
  }

  @override
  void didUpdateWidget(PaginatedTweetList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pagingController, widget.pagingController)) {
      oldWidget.pagingController.removePageRequestListener(_handlePageRequest);
      oldWidget.pagingController.removeListener(_onControllerChanged);
      widget.pagingController.addPageRequestListener(_handlePageRequest);
      widget.pagingController.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.pagingController.removePageRequestListener(_handlePageRequest);
    widget.pagingController.removeListener(_onControllerChanged);
    _refreshController?.unregister(_showRefresh);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
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

  Future<void> _handlePageRequest(String? cursor) async {
    try {
      final result = await widget.loadPage(cursor);
      if (!mounted) return;
      // Terminate pagination when the page is empty, when there's no next
      // cursor, or when the API returned the same cursor twice (would
      // otherwise loop forever).
      final next = result.nextCursor;
      if (result.chains.isEmpty ||
          next == null ||
          next.isEmpty ||
          next == widget.pagingController.nextPageKey) {
        widget.pagingController.appendLastPage(result.chains);
      } else {
        widget.pagingController.appendPage(result.chains, next);
      }
    } catch (e, stackTrace) {
      if (mounted) {
        widget.pagingController.error = [e, stackTrace];
      }
    }
  }

  /// Soft refresh used by the pull-to-refresh gesture. Runs the caller's
  /// [onRefresh] side effects, then reloads the first page *without* clearing
  /// the current items. This keeps the existing tweets visible — and lets the
  /// RefreshIndicator show its own small spinner on top — instead of nulling
  /// the list and replacing it with a full-screen progress indicator the way
  /// PagingController.refresh() does. Awaited so the spinner stays until done.
  Future<void> _handleRefresh() async {
    final controller = widget.pagingController;
    await widget.onRefresh?.call();
    if (!mounted) return;
    try {
      final result = await widget.loadPage(controller.firstPageKey);
      if (!mounted) return;
      final next = result.nextCursor;
      final isLast = result.chains.isEmpty || next == null || next.isEmpty;
      controller.value = PagingState<String?, TweetChain>(
        nextPageKey: isLast ? null : next,
        itemList: result.chains,
        error: null,
      );
    } catch (e, stackTrace) {
      if (mounted) {
        controller.error = [e, stackTrace];
      }
    }
  }

  // True while we should display the cached preview: the first page hasn't
  // loaded yet, there's no error to surface, and we actually have cached tweets.
  bool get _showingPreview {
    final preview = widget.firstPagePreview;
    final controller = widget.pagingController;
    return preview != null && preview.isNotEmpty && controller.itemList == null && controller.error == null;
  }

  // The PagedListView normally kicks off the first page when it mounts. While
  // the preview replaces it, nothing does — so trigger the load ourselves once.
  void _maybeStartFirstLoad() {
    if (_firstLoadStarted) return;
    final controller = widget.pagingController;
    if (controller.itemList != null || controller.error != null) return;
    _firstLoadStarted = true;
    if (widget.onRefresh == null) {
      _handlePageRequest(controller.firstPageKey);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final refreshState = _refreshKey.currentState;
      if (refreshState != null) {
        _pendingInitialLoad = true;
        refreshState.show();
      } else {
        _handlePageRequest(controller.firstPageKey);
      }
    });
  }

  Future<void> _onRefreshTriggered() async {
    if (_pendingInitialLoad) {
      _pendingInitialLoad = false;
      await _handlePageRequest(widget.pagingController.firstPageKey);
      return;
    }
    await _handleRefresh();
  }

  Widget _wrapWithRefresh(Widget child) {
    if (widget.onRefresh == null) return child;
    return RefreshIndicator(key: _refreshKey, onRefresh: _onRefreshTriggered, child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (_showingPreview) {
      _maybeStartFirstLoad();
      return _wrapWithRefresh(CachedTweetList(widget.firstPagePreview!, username: widget.username));
    }

    final list = PagedListView<String?, TweetChain>(
      padding: const EdgeInsets.only(top: 4),
      pagingController: widget.pagingController,
      addAutomaticKeepAlives: false,
      builderDelegate: PagedChildBuilderDelegate(
        itemBuilder: (context, chain, index) => _buildChain(context, chain),
        firstPageProgressIndicatorBuilder: (context) => const Center(child: CircularProgressIndicator()),
        firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
          error: widget.pagingController.error[0],
          stackTrace: widget.pagingController.error[1],
          prefix: widget.firstPageErrorPrefix,
          onRetry: () => _handlePageRequest(widget.pagingController.firstPageKey),
        ),
        newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
          error: widget.pagingController.error[0],
          stackTrace: widget.pagingController.error[1],
          prefix: widget.newPageErrorPrefix,
          onRetry: () => _handlePageRequest(widget.pagingController.nextPageKey),
        ),
        noItemsFoundIndicatorBuilder: (context) => Center(child: Text(widget.emptyMessage)),
      ),
    );

    return _wrapWithRefresh(list);
  }
}
