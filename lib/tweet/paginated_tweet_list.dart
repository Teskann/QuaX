import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/client/client.dart';
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

  const PaginatedTweetList({
    super.key,
    required this.pagingController,
    required this.loadPage,
    required this.username,
    required this.firstPageErrorPrefix,
    required this.newPageErrorPrefix,
    required this.emptyMessage,
    this.onRefresh,
  });

  @override
  State<PaginatedTweetList> createState() => _PaginatedTweetListState();
}

class _PaginatedTweetListState extends State<PaginatedTweetList> {
  @override
  void initState() {
    super.initState();
    widget.pagingController.addPageRequestListener(_handlePageRequest);
  }

  @override
  void didUpdateWidget(PaginatedTweetList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.pagingController, widget.pagingController)) {
      oldWidget.pagingController.removePageRequestListener(_handlePageRequest);
      widget.pagingController.addPageRequestListener(_handlePageRequest);
    }
  }

  @override
  void dispose() {
    widget.pagingController.removePageRequestListener(_handlePageRequest);
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final list = PagedListView<String?, TweetChain>(
      padding: const EdgeInsets.only(top: 4),
      pagingController: widget.pagingController,
      addAutomaticKeepAlives: false,
      builderDelegate: PagedChildBuilderDelegate(
        itemBuilder: (context, chain, index) {
          return TweetConversation(
            id: chain.id,
            tweets: chain.tweets,
            username: widget.username,
            isPinned: chain.isPinned,
          );
        },
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

    final onRefresh = widget.onRefresh;
    if (onRefresh == null) return list;

    return RefreshIndicator(onRefresh: onRefresh, child: list);
  }
}
