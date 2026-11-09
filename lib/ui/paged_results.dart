import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/paging.dart';

/// A list that loads its items page by page, with an error card when a page fails.
class PagedResults<T> extends StatelessWidget {
  final PagingController<int, T> controller;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final ErrorPrefix errorPrefix;

  const PagedResults({super.key, required this.controller, required this.itemBuilder, required this.errorPrefix});

  @override
  Widget build(BuildContext context) {
    return PagingListener<int, T>(
      controller: controller,
      builder: (context, state, fetchNextPage) => PagedListView<int, T>(
        state: state,
        fetchNextPage: fetchNextPage,
        builderDelegate: PagedChildBuilderDelegate(
          itemBuilder: (context, item, index) => itemBuilder(context, item),
          firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: errorPrefix,
            onRetry: fetchNextPage,
          ),
          newPageErrorIndicatorBuilder: (context) => ErrorCard(
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: errorPrefix,
            onRetry: fetchNextPage,
          ),
          noItemsFoundIndicatorBuilder: (context) => Center(child: Text(L10n.of(context).no_results)),
        ),
      ),
    );
  }
}
