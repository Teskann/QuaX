import 'package:extended_image/extended_image.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/community/community.dart';
import 'package:quax/community/community_members_screen.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/ui/locale_fallback.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/urls.dart';
import 'package:share_plus/share_plus.dart';

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
              _ShareButton(communityId: community.id),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => CommunityMembersScreen.open(context, community.id, community.name),
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
    final members = NumberFormat.compact(locale: formattingLocale()).format(community.memberCount);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Facepile(urls: community.memberAvatarUrls),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: members,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextSpan(text: ' ${L10n.of(context).community_members}'),
            ],
          ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

class _Facepile extends StatelessWidget {
  final List<String> urls;

  const _Facepile({required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        children: urls
            .take(5)
            .map((url) => Align(widthFactor: 0.7, child: UserAvatar(uri: url, size: 24)))
            .toList(growable: false),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final String communityId;

  const _ShareButton({required this.communityId});

  @override
  Widget build(BuildContext context) {
    final link = '${shareBaseUrlOf(PrefService.of(context))}/i/communities/$communityId';
    return IconButton(
      icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary, semanticLabel: L10n.of(context).share),
      onPressed: () => SharePlus.instance.share(ShareParams(text: link)),
    );
  }
}

class CommunityBanner extends StatelessWidget {
  final String url;
  final String name;

  const CommunityBanner({super.key, required this.url, required this.name});

  void _openFullScreen(BuildContext context) => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          TweetMediaView(initialIndex: 0, media: [createMediaFromUrl(url, null)], username: name, tweetMedia: false),
    ),
  );

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: L10n.of(context).profile_banner,
    child: GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ExtendedImage.network(url, fit: BoxFit.cover),
    ),
  );
}
