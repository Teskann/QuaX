import 'package:flutter/material.dart';

import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/utils/paging.dart';

class ProfileFollows extends StatefulWidget {
  final UserWithExtra user;
  final String type;

  const ProfileFollows({super.key, required this.user, required this.type});

  @override
  State<ProfileFollows> createState() => _ProfileFollowsState();
}

class _ProfileFollowsState extends State<ProfileFollows> with AutomaticKeepAliveClientMixin<ProfileFollows> {
  late final CursorPagingController<int, UserWithExtra> _paging;
  PagingController<int, UserWithExtra> get _pagingController => _paging.pagingController;

  final int _pageSize = 200;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _paging = CursorPagingController<int, UserWithExtra>(_fetchPage);
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  Future<CursorPage<int, UserWithExtra>> _fetchPage(int? cursor) async {
    var result = await Twitter.getProfileFollows(widget.user.screenName!, widget.type,
        cursor: cursor, count: _pageSize, id: widget.user.idStr);

    final next = result.cursorBottom;
    // Cursor didn't advance -> nothing new, drop the duplicate page.
    if (next == cursor) return (items: const <UserWithExtra>[], nextCursor: null);
    // cursorBottom 0 (or absent) marks the final page; keep its users.
    if (next == null || next == 0) return (items: result.users, nextCursor: null);
    return (items: result.users, nextCursor: next);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
        appBar: AppBar(
          title: Text(widget.type == 'following' ? L10n.of(context).following : L10n.of(context).followers),
        ),
        body: PagingListener<int, UserWithExtra>(
          controller: _pagingController,
          builder: (context, state, fetchNextPage) => PagedListView<int, UserWithExtra>(
            padding: EdgeInsets.zero,
            state: state,
            fetchNextPage: fetchNextPage,
            addAutomaticKeepAlives: false,
            builderDelegate: PagedChildBuilderDelegate(
              itemBuilder: (context, user, index) => UserTile(user: UserSubscription.fromUser(user)),
              firstPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
                error: pagingErrorOf(state)?.error,
                stackTrace: pagingErrorOf(state)?.stackTrace,
                prefix: L10n.of(context).unable_to_load_the_list_of_follows,
                onRetry: fetchNextPage,
              ),
              newPageErrorIndicatorBuilder: (context) => FullPageErrorWidget(
                error: pagingErrorOf(state)?.error,
                stackTrace: pagingErrorOf(state)?.stackTrace,
                prefix: L10n.of(context).unable_to_load_the_next_page_of_follows,
                onRetry: fetchNextPage,
              ),
              noItemsFoundIndicatorBuilder: (context) {
                var text = widget.type == 'following'
                    ? L10n.of(context).this_user_does_not_follow_anyone
                    : L10n.of(context).this_user_does_not_have_anyone_following_them;

                return Center(
                  child: Text(text),
                );
              },
            ),
          ),
        ));
  }
}
