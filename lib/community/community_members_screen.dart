import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/paging.dart';

class CommunityMembersScreen extends StatefulWidget {
  final String communityId;
  final String communityName;

  const CommunityMembersScreen({super.key, required this.communityId, required this.communityName});

  static Future<void> open(BuildContext context, String communityId, String communityName) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CommunityMembersScreen(communityId: communityId, communityName: communityName)),
  );

  @override
  State<CommunityMembersScreen> createState() => _CommunityMembersScreenState();
}

class _CommunityMembersScreenState extends State<CommunityMembersScreen> {
  late final _members = CursorPagingController<String, UserWithExtra>(
    (cursor) => Twitter.getCommunityMembers(widget.communityId, cursor: cursor),
  );

  @override
  void dispose() {
    _members.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).community_members_of(widget.communityName))),
      body: PagingListener<int, UserWithExtra>(
        controller: _members.pagingController,
        builder: (context, state, fetchNextPage) => PagedListView<int, UserWithExtra>(
          state: state,
          fetchNextPage: fetchNextPage,
          builderDelegate: PagedChildBuilderDelegate(
            itemBuilder: (context, user, index) => UserTile(user: UserSubscription.fromUser(user)),
            firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: (l10n) => l10n.unable_to_load_the_members,
              onRetry: fetchNextPage,
            ),
            newPageErrorIndicatorBuilder: (context) => ErrorCard(
              error: pagingErrorOf(state)?.error,
              stackTrace: pagingErrorOf(state)?.stackTrace,
              prefix: (l10n) => l10n.unable_to_load_the_members,
              onRetry: fetchNextPage,
            ),
            noItemsFoundIndicatorBuilder: (context) => Center(child: Text(L10n.of(context).no_results)),
          ),
        ),
      ),
    );
  }
}
