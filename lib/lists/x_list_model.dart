import 'package:quax/client/client.dart';
import 'package:quax/lists/x_list.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/loaded_store.dart';
import 'package:quax/utils/paging.dart';

/// A list and the first page of its members. The page gives the photos of a few members, and the members page
/// starts from it.
class LoadedXList {
  final XList list;

  /// Null when X did not send the members. The list still shows, without their photos.
  final CursorPage<String, UserWithExtra>? firstMembers;

  const LoadedXList(this.list, this.firstMembers);
}

class XListModel extends LoadedStore<LoadedXList> {
  XListModel(String id) : super(LoadedXList(XList(id: id, name: ''), null), () => _load(id));

  static Future<LoadedXList> _load(String id) async {
    final members = Twitter.getListMembers(id)
        .then<CursorPage<String, UserWithExtra>?>((page) => page, onError: (_) => null);
    final list = await Twitter.getList(id);
    return LoadedXList(list, await members);
  }
}
