import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/user.dart';

typedef AccountsLoader = Future<List<Account>> Function();
typedef ProfileLoader = Future<UserWithExtra> Function(String screenName);

/// The account the X design shows in the home header and in its side drawer.
class XAccount {
  final String screenName;
  final String? name;
  final String? avatarUrl;
  final int? following;
  final int? followers;

  const XAccount({required this.screenName, this.name, this.avatarUrl, this.following, this.followers});
}

class XAccountState {
  /// Whether the accounts were looked up yet. Until then, the UI must not claim there is no account.
  final bool loaded;
  final XAccount? account;

  const XAccountState({required this.loaded, this.account});

  static const loading = XAccountState(loaded: false);
  static const none = XAccountState(loaded: true);
}

Future<UserWithExtra> _lookupProfile(String screenName) async => (await Twitter.getProfileByScreenName(screenName)).user;

/// Loads the first account and its profile once, however many widgets ask for it.
class XAccountModel extends Store<XAccountState> {
  final AccountsLoader _accounts;
  final ProfileLoader _profile;
  bool _requested = false;

  XAccountModel({AccountsLoader? accounts, ProfileLoader? profile})
      : _accounts = accounts ?? getAccounts,
        _profile = profile ?? _lookupProfile,
        super(XAccountState.loading);

  Future<void> loadOnce() async {
    if (_requested) return;
    _requested = true;
    await execute(_load);
  }

  Future<XAccountState> _load() async {
    final screenNames = (await _accounts()).map((e) => e.screenName).nonNulls;
    if (screenNames.isEmpty) return XAccountState.none;
    return XAccountState(loaded: true, account: await _describe(screenNames.first));
  }

  Future<XAccount> _describe(String screenName) async {
    try {
      final user = await _profile(screenName);
      return XAccount(
        screenName: screenName,
        name: user.name,
        avatarUrl: user.profileImageUrlHttps,
        following: user.friendsCount,
        followers: user.followersCount,
      );
    } catch (_) {
      return XAccount(screenName: screenName);
    }
  }
}
