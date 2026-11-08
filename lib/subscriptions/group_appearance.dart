import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/database/entities.dart';

typedef GroupTone = ({Color background, Color foreground});

final _schemeCache = <(int, int, Brightness), ColorScheme>{};

/// The color of a group, adapted to the theme: leaning toward its accent color, light or dark like it.
GroupTone groupTone(BuildContext context, Color? color) {
  final theme = Theme.of(context);
  final primary = theme.colorScheme.primary;
  if (color == null) {
    return (background: theme.colorScheme.secondaryContainer, foreground: theme.colorScheme.onSecondaryContainer);
  }
  final scheme = _schemeCache.putIfAbsent((
    color.toARGB32(),
    primary.toARGB32(),
    theme.brightness,
  ), () => ColorScheme.fromSeed(seedColor: color.harmonizeWith(primary), brightness: theme.brightness));
  return (background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer);
}

const _maxShownGroupTags = 2;

class GroupTags extends StatelessWidget {
  final List<SubscriptionGroup> groups;

  const GroupTags({super.key, required this.groups});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...groups.take(_maxShownGroupTags).map((group) {
          final tone = groupTone(context, group.color);
          return _Tag(
            icon: group.iconData,
            label: group.name,
            background: tone.background,
            foreground: tone.foreground,
          );
        }),
        if (groups.length > _maxShownGroupTags)
          _Tag(
            label: '+${groups.length - _maxShownGroupTags}',
            background: colors.surfaceContainerHighest,
            foreground: colors.onSurfaceVariant,
          ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color background;
  final Color foreground;

  const _Tag({this.icon, required this.label, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: foreground), const SizedBox(width: 4)],
          Flexible(
            child: Text(label, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
