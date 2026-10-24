import 'package:extended_image/extended_image.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/community/community.dart';
import 'package:quax/community/community_screen.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/locale_fallback.dart';

class CommunityTile extends StatelessWidget {
  final Community community;

  const CommunityTile({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final members = NumberFormat.compact(locale: formattingLocale()).format(community.memberCount);
    final banner = community.bannerUrl;

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 48,
          child: banner == null ? const Icon(Icons.groups) : ExtendedImage.network(banner, fit: BoxFit.cover),
        ),
      ),
      title: Text(community.name),
      subtitle: Text(['$members ${L10n.of(context).community_members}', ?community.topic].join(' · ')),
      onTap: () => Navigator.pushNamed(context, routeCommunity, arguments: CommunityScreenArguments(community.id)),
    );
  }
}
