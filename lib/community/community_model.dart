import 'package:quax/client/client.dart';
import 'package:quax/community/community.dart';
import 'package:quax/utils/loaded_store.dart';

class CommunityModel extends LoadedStore<Community> {
  CommunityModel(String id) : super(Community(id: id, name: ''), () => Twitter.getCommunity(id));
}
