import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/community/community.dart';
import 'package:quax/community/community_tile.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/search/search_model.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/paging.dart';

class CommunitySearchResults extends StatelessWidget {
  final SearchCommunitiesPagination model;

  const CommunitySearchResults({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return PagingListener<int, Community>(
      controller: model.pagingController,
      builder: (context, state, fetchNextPage) => PagedListView<int, Community>(
        state: state,
        fetchNextPage: fetchNextPage,
        builderDelegate: PagedChildBuilderDelegate(
          itemBuilder: (context, community, index) => CommunityTile(community: community),
          firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: (l10n) => l10n.unable_to_load_the_search_results,
            onRetry: fetchNextPage,
          ),
          newPageErrorIndicatorBuilder: (context) => ErrorCard(
            error: pagingErrorOf(state)?.error,
            stackTrace: pagingErrorOf(state)?.stackTrace,
            prefix: (l10n) => l10n.unable_to_load_the_search_results,
            onRetry: fetchNextPage,
          ),
          noItemsFoundIndicatorBuilder: (context) => Center(child: Text(L10n.of(context).no_results)),
        ),
      ),
    );
  }
}
