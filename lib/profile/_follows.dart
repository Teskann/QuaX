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
  late final CursorPagingController<String, UserWithExtra> _paging;
  PagingController<int, UserWithExtra> get _pagingController => _paging.pagingController;

  final int _pageSize = 200;
  final Set<String> _seenIds = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _paging = CursorPagingController<String, UserWithExtra>(_fetchPage);
  }

  @override
  void dispose() {
    _paging.dispose();
    super.dispose();
  }

  Future<CursorPage<String, UserWithExtra>> _fetchPage(String? cursor) async {
    var result = await Twitter.getProfileFollows(widget.user.screenName!, widget.type,
        cursor: cursor, count: _pageSize, id: widget.user.idStr);

    final next = result.cursorBottom;
    final fresh = result.users.where((u) => u.idStr != null && _seenIds.add(u.idStr!)).toList();
    final end = next == null || next.isEmpty || next == '0' || next == cursor || fresh.isEmpty;
    return (items: fresh, nextCursor: end ? null : next);
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
