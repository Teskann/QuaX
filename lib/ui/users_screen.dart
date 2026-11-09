import 'package:material_ui/material_ui.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/paged_results.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/paging.dart';

/// Accounts loaded page by page, such as the members of a community or the followers of a list.
class UsersScreen extends StatefulWidget {
  final String title;
  final CursorPageFetcher<String, UserWithExtra> fetch;
  final ErrorPrefix errorPrefix;

  /// A first page already loaded, so that it is not asked again.
  final CursorPage<String, UserWithExtra>? firstPage;

  const UsersScreen({super.key, required this.title, required this.fetch, required this.errorPrefix, this.firstPage});

  static Future<void> open(BuildContext context, UsersScreen screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final _users = CursorPagingController<String, UserWithExtra>(widget.fetch);

  @override
  void initState() {
    super.initState();
    final firstPage = widget.firstPage;
    if (firstPage != null) {
      _users.replaceFirstPage(firstPage.items, firstPage.nextCursor);
    }
  }

  @override
  void dispose() {
    _users.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: PagedResults<UserWithExtra>(
        controller: _users.pagingController,
        itemBuilder: (context, user) => UserTile(user: UserSubscription.fromUser(user)),
        errorPrefix: widget.errorPrefix,
      ),
    );
  }
}
