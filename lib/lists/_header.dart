import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/lists/x_list.dart';
import 'package:quax/lists/x_list_model.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/ui/count_label.dart';
import 'package:quax/ui/facepile.dart';
import 'package:quax/ui/share_link_button.dart';
import 'package:quax/ui/tap_area.dart';
import 'package:quax/ui/users_screen.dart';
import 'package:quax/user.dart';

/// The name of a list, what it is about, who made it and how many accounts it holds.
class XListHeader extends StatelessWidget {
  final LoadedXList loaded;

  const XListHeader({super.key, required this.loaded});

  @override
  Widget build(BuildContext context) {
    final list = loaded.list;
    final theme = Theme.of(context);
    final owner = list.owner;
    final description = list.description;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(list.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ),
              ShareLinkButton(path: '/i/lists/${list.id}'),
            ],
          ),
          if (description != null) ...[const SizedBox(height: 4), Text(description)],
          if (owner != null) _Owner(owner: owner),
          _Counts(loaded: loaded),
        ],
      ),
    );
  }
}

class _Owner extends StatelessWidget {
  final XListOwner owner;

  const _Owner({required this.owner});

  @override
  Widget build(BuildContext context) {
    return TapArea(
      onTap: () => Navigator.pushNamed(
        context,
        routeProfile,
        arguments: ProfileScreenArguments(owner.id, owner.screenName, null),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(uri: owner.avatarUrl, size: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: owner.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: ' @${owner.screenName}'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// How many members and followers the list has, each with the photos of a few of them. Tapping one shows them.
class _Counts extends StatelessWidget {
  final LoadedXList loaded;

  const _Counts({required this.loaded});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final list = loaded.list;
    final members = loaded.firstMembers?.items ?? const [];
    return Wrap(
      spacing: 16,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        XListCount(
          photos: members.map((user) => user.profileImageUrlHttps).nonNulls.take(3).toList(),
          count: list.memberCount,
          label: l10n.members_after_count(list.memberCount),
          onTap: () => openListMembers(context, loaded),
        ),
        XListCount(
          photos: list.followerAvatarUrls,
          count: list.followerCount,
          label: l10n.followers_after_count(list.followerCount),
          onTap: () => _openFollowers(context, list),
        ),
      ],
    );
  }

  void _openFollowers(BuildContext context, XList list) => UsersScreen.open(
    context,
    UsersScreen(
      title: L10n.of(context).list_followers_of(list.name),
      fetch: (cursor) => Twitter.getListFollowers(list.id, cursor: cursor),
      errorPrefix: (l10n) => l10n.unable_to_load_the_followers,
    ),
  );
}

/// Opens the members of a list, starting from the page already loaded.
void openListMembers(BuildContext context, LoadedXList loaded) => UsersScreen.open(
  context,
  UsersScreen(
    title: L10n.of(context).list_members_of(loaded.list.name),
    fetch: (cursor) => Twitter.getListMembers(loaded.list.id, cursor: cursor),
    errorPrefix: (l10n) => l10n.unable_to_load_the_members,
    firstPage: loaded.firstMembers,
  ),
);

/// A few photos, then a count of accounts. Tapping it shows the accounts.
class XListCount extends StatelessWidget {
  final List<String> photos;
  final int count;
  final String label;
  final VoidCallback onTap;

  const XListCount({super.key, required this.photos, required this.count, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => TapArea(
    onTap: onTap,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Facepile(urls: photos),
        CountLabel(count: count, label: label, tappable: true),
      ],
    ),
  );
}
