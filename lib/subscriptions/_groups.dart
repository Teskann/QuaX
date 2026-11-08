import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/subscriptions/group_appearance.dart';
import 'package:quax/subscriptions/group_editor.dart';

class GroupsHeader extends StatelessWidget {
  final bool collapsed;
  final VoidCallback onToggleCollapsed;

  const GroupsHeader({super.key, required this.collapsed, required this.onToggleCollapsed});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      child: Row(
        children: [
          Expanded(child: SectionTitle(l10n.groups)),
          IconButton(
            onPressed: onToggleCollapsed,
            tooltip: collapsed ? l10n.show_groups : l10n.hide_groups,
            icon: AnimatedRotation(
              turns: collapsed ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.expand_less),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant));
  }
}

class GroupsGrid extends StatelessWidget {
  final List<SubscriptionGroup> groups;

  const GroupsGrid({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 100,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) => index < groups.length ? GroupTile(group: groups[index]) : const _NewGroupTile(),
    );
  }
}

/// Opens the feed of the group, or its editor on a long press.
class GroupTile extends StatelessWidget {
  final SubscriptionGroup group;

  const GroupTile({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final tone = groupTone(context, group.color);
    void edit() => openGroupEditor(context, id: group.id);
    return Semantics(
      customSemanticsActions: {CustomSemanticsAction(label: L10n.of(context).edit_group): edit},
      child: _GroupGridTile(
        icon: group.iconData,
        label: group.name,
        background: tone.background,
        foreground: tone.foreground,
        onTap: () => Navigator.pushNamed(
          context,
          routeGroup,
          arguments: GroupScreenArguments(id: group.id, name: group.name),
        ),
        onLongPress: edit,
      ),
    );
  }
}

class _NewGroupTile extends StatelessWidget {
  const _NewGroupTile();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _GroupGridTile(
      icon: Icons.add,
      label: L10n.of(context).new_group,
      foreground: colors.primary,
      border: BorderSide(color: colors.outlineVariant),
      onTap: () => openGroupEditor(context),
    );
  }
}

class _GroupGridTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? background;
  final Color foreground;
  final BorderSide border;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _GroupGridTile({
    required this.icon,
    required this.label,
    this.background,
    required this.foreground,
    this.border = BorderSide.none,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: border),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(6),
          // With a large system font, the content shrinks so that the tile stays square
          child: LayoutBuilder(
            builder: (context, box) => FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: box.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 22, color: foreground),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground, height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
