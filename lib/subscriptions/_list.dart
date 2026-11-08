import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/group_appearance.dart';
import 'package:quax/subscriptions/subscription_display.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/subscription_order.dart';

class SubscriptionRow extends StatelessWidget {
  final Subscription subscription;
  final List<SubscriptionGroup> groups;
  final bool selected;
  final bool selecting;
  final VoidCallback onToggleSelected;

  final int? reorderIndex;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const SubscriptionRow({
    super.key,
    required this.subscription,
    required this.groups,
    required this.selected,
    required this.selecting,
    required this.onToggleSelected,
    this.reorderIndex,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.move_up): ?onMoveUp,
        CustomSemanticsAction(label: l10n.move_down): ?onMoveDown,
      },
      child: Material(
        color: selected ? colors.secondaryContainer.withValues(alpha: 0.6) : Colors.transparent,
        child: InkWell(
          onTap: selecting ? onToggleSelected : () => openSubscription(context, subscription),
          onLongPress: onToggleSelected,
          // The tags sit below the tile, so that the picture lines up with the name and the handle only
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                selected: selected,
                // Without padding below, the tags follow the handle as closely as lines of text
                contentPadding: EdgeInsetsDirectional.only(start: 16, end: 24, top: 8, bottom: groups.isEmpty ? 8 : 0),
                minVerticalPadding: 0,
                minTileHeight: 0,
                leading: _selectableAvatar(l10n),
                title: _SubscriptionTitle(subscription: subscription),
                subtitle: _SubscriptionHandle(subscription: subscription),
                trailing: reorderIndex == null
                    ? null
                    : ReorderableDragStartListener(
                        index: reorderIndex!,
                        child: const ExcludeSemantics(child: Icon(Icons.drag_indicator)),
                      ),
              ),
              if (groups.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: _textStart, end: 16, top: 7, bottom: 8),
                  child: GroupTags(groups: groups),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectableAvatar(L10n l10n) => Semantics(
    button: true,
    selected: selected,
    label: l10n.select_subscription(subscription.name),
    excludeSemantics: true,
    child: InkResponse(
      onTap: onToggleSelected,
      radius: subscriptionAvatarSize / 2,
      child: SubscriptionAvatar(subscription: subscription, selected: selected),
    ),
  );
}

/// Where the text of a tile starts: its padding, the picture and the gap after it.
const double _textStart = 16 + subscriptionAvatarSize + 16;

class _SubscriptionTitle extends StatelessWidget {
  final Subscription subscription;

  const _SubscriptionTitle({required this.subscription});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(child: Text(subscription.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (subscription.verified) ...[
          const SizedBox(width: 6),
          Icon(Icons.verified, size: 14, color: Theme.of(context).colorScheme.primary),
        ],
      ],
    );
  }
}

class _SubscriptionHandle extends StatelessWidget {
  final Subscription subscription;

  const _SubscriptionHandle({required this.subscription});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final hiddenFromFeed = SubscriptionKind.of(subscription).canHideFromMainFeed && !subscription.inFeed;
    return Row(
      children: [
        Flexible(child: Text(subscriptionHandle(l10n, subscription), maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (hiddenFromFeed) ...[
          const SizedBox(width: 6),
          Icon(Icons.visibility_off_outlined, size: 16, semanticLabel: l10n.hidden_from_main_feed),
        ],
      ],
    );
  }
}

class SortControls extends StatelessWidget {
  final SubscriptionOrder order;
  final VoidCallback onNextSort;
  final VoidCallback onReverse;

  const SortControls({super.key, required this.order, required this.onNextSort, required this.onReverse});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final label = switch (order.sort) {
      SubscriptionSort.name => l10n.name,
      SubscriptionSort.screenName => l10n.username,
      SubscriptionSort.createdAt => l10n.date_subscribed,
      SubscriptionSort.custom => l10n.custom_order,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (order.sort != SubscriptionSort.custom)
          IconButton(
            onPressed: onReverse,
            tooltip: l10n.reverse_order,
            icon: Icon(order.ascending ? Icons.arrow_upward : Icons.arrow_downward, size: 20),
          ),
        Tooltip(
          message: l10n.sort_by,
          child: TextButton.icon(
            onPressed: onNextSort,
            icon: const Icon(Icons.swap_vert, size: 18),
            label: Text(label, semanticsLabel: l10n.sort_by_value(label)),
          ),
        ),
      ],
    );
  }
}

class EmptySubscriptions extends StatelessWidget {
  final IconData icon;
  final String message;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;

  const EmptySubscriptions({
    super.key,
    required this.icon,
    required this.message,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: color),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color),
          ),
          const SizedBox(height: 16),
          FilledButton.tonalIcon(onPressed: onAction, icon: Icon(actionIcon, size: 18), label: Text(actionLabel)),
        ],
      ),
    );
  }
}
