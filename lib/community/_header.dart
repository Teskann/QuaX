import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/community.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/count_label.dart';
import 'package:quax/ui/facepile.dart';
import 'package:quax/ui/share_link_button.dart';
import 'package:quax/ui/tap_area.dart';
import 'package:quax/ui/users_screen.dart';
import 'package:quax/user.dart';

class CommunityHeader extends StatelessWidget {
  final Community community;

  const CommunityHeader({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  community.name,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              FollowButton(
                subscription: CommunitySubscription.fromCommunity(community),
                color: theme.colorScheme.primary,
              ),
              ShareLinkButton(path: '/i/communities/${community.id}'),
            ],
          ),
          TapArea(
            onTap: () => UsersScreen.open(
              context,
              UsersScreen(
                title: L10n.of(context).community_members_of(community.name),
                fetch: (cursor) => Twitter.getCommunityMembers(community.id, cursor: cursor),
                errorPrefix: (l10n) => l10n.unable_to_load_the_members,
              ),
            ),
            child: CommunityMembersSummary(community: community),
          ),
        ],
      ),
    );
  }
}

class CommunityMembersSummary extends StatelessWidget {
  final Community community;

  const CommunityMembersSummary({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Facepile(urls: community.memberAvatarUrls),
        CountLabel(
          count: community.memberCount,
          label: L10n.of(context).members_after_count(community.memberCount),
          tappable: true,
        ),
      ],
    );
  }
}
