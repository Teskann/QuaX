import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/community/community_screen.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/search/search.dart';
import 'package:quax/subscriptions/subscription_filters.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/user.dart';

extension SubscriptionKindDisplay on SubscriptionKind {
  IconData get icon => switch (this) {
    SubscriptionKind.user => Icons.person,
    SubscriptionKind.search => Icons.saved_search,
    SubscriptionKind.community => Icons.groups,
  };

  String label(L10n l10n) => switch (this) {
    SubscriptionKind.user => l10n.kind_accounts,
    SubscriptionKind.search => l10n.kind_searches,
    SubscriptionKind.community => l10n.kind_communities,
  };

  String count(L10n l10n, int count) => switch (this) {
    SubscriptionKind.user => l10n.n_accounts(count),
    SubscriptionKind.search => l10n.n_searches(count),
    SubscriptionKind.community => l10n.n_communities(count),
  };

  IconData get followIcon => switch (this) {
    SubscriptionKind.user || SubscriptionKind.search => Icons.person_add,
    SubscriptionKind.community => Icons.group_add,
  };

  IconData get unfollowIcon => switch (this) {
    SubscriptionKind.user || SubscriptionKind.search => Icons.person_remove,
    SubscriptionKind.community => Icons.group_remove,
  };

  /// The search tab that finds this kind.
  SearchTab get searchTab => switch (this) {
    SubscriptionKind.user => SearchTab.people,
    SubscriptionKind.search => SearchTab.top,
    SubscriptionKind.community => SearchTab.communities,
  };
}

void openSubscription(BuildContext context, Subscription subscription) => switch (subscription) {
  UserSubscription() => Navigator.pushNamed(
    context,
    routeProfile,
    arguments: ProfileScreenArguments(subscription.id, subscription.screenName, null),
  ),
  SearchSubscription() => Navigator.pushNamed(
    context,
    routeSearch,
    arguments: SearchArguments(SearchTab.top, focusInputOnOpen: false, query: subscription.id),
  ),
  CommunitySubscription() => Navigator.pushNamed(
    context,
    routeCommunity,
    arguments: CommunityScreenArguments(subscription.id),
  ),
};

/// The size of the picture of a subscription in lists.
const double subscriptionAvatarSize = 40;

class SubscriptionAvatar extends StatelessWidget {
  final Subscription subscription;
  final bool selected;

  const SubscriptionAvatar({super.key, required this.subscription, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (selected) {
      return CircleAvatar(
        radius: subscriptionAvatarSize / 2,
        backgroundColor: colors.primary,
        child: Icon(Icons.check, color: colors.onPrimary),
      );
    }
    return switch (subscription) {
      UserSubscription(:final profileImageUrlHttps) => UserAvatar(
        uri: profileImageUrlHttps,
        size: subscriptionAvatarSize,
      ),
      SearchSubscription() => _kindAvatar(colors, SubscriptionKind.search, null),
      CommunitySubscription(:final bannerUrl) => _kindAvatar(colors, SubscriptionKind.community, bannerUrl),
    };
  }

  /// The picture, or the icon of the kind when there is no picture.
  Widget _kindAvatar(ColorScheme colors, SubscriptionKind kind, String? imageUrl) {
    return CircleAvatar(
      radius: subscriptionAvatarSize / 2,
      backgroundColor: colors.tertiaryContainer,
      foregroundImage: imageUrl == null ? null : ExtendedNetworkImageProvider(imageUrl),
      child: Icon(kind.icon, color: colors.onTertiaryContainer),
    );
  }
}

String subscriptionHandle(L10n l10n, Subscription subscription) => switch (subscription) {
  UserSubscription() => '@${subscription.screenName}',
  SearchSubscription() => l10n.search_term,
  CommunitySubscription() => l10n.community,
};

/// "3 accounts · 1 search"
String membersSummary(BuildContext context, Iterable<Subscription> members) {
  final l10n = L10n.of(context);
  final parts = countByKind(members).entries.map((e) => e.key.count(l10n, e.value));
  return parts.isEmpty ? l10n.no_members_yet : parts.join(' · ');
}

class KindFilters extends StatelessWidget {
  final List<Subscription> subscriptions;
  final SubscriptionKind? chosen;
  final ValueChanged<SubscriptionKind?> onChosen;

  const KindFilters({super.key, required this.subscriptions, required this.chosen, required this.onChosen});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final counts = countByKind(subscriptions);
    Widget chip(String label, int count, SubscriptionKind? kind) => FilterChip(
      label: Text(l10n.label_with_count(label, count)),
      labelStyle: Theme.of(context).textTheme.labelMedium,
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      // Keeps the spacing around the chips to the padding below
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selected: chosen == kind,
      onSelected: (_) => onChosen(kind),
    );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Wrap(
        spacing: 8,
        children: [
          chip(l10n.all, subscriptions.length, null),
          for (final kind in kindsToFilterBy(subscriptions, chosen)) chip(kind.label(l10n), counts[kind] ?? 0, kind),
        ],
      ),
    );
  }
}
