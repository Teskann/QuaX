import 'package:material_ui/material_ui.dart';
import 'package:quax/community/community.dart';
import 'package:quax/community/community_screen.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/banner_tile.dart';
import 'package:quax/ui/count_label.dart';

class CommunityTile extends StatelessWidget {
  final Community community;

  const CommunityTile({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final members = formatCount(community.memberCount);
    return BannerTile(
      bannerUrl: community.bannerUrl,
      icon: Icons.groups,
      title: community.name,
      subtitle: ['$members ${L10n.of(context).members_after_count(community.memberCount)}', ?community.topic].join(' · '),
      onTap: () => Navigator.pushNamed(context, routeCommunity, arguments: CommunityScreenArguments(community.id)),
    );
  }
}
