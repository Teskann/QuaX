import 'dart:convert';

import 'package:flutter/material.dart' as fm;
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/group_appearance.dart';
import 'package:quax/subscriptions/group_editor_model.dart';

/// The default color, then the color of each Material hue.
final List<Color?> _palette = [null, ...Colors.primaries];

final List<Color?> _quickColors = [null, Colors.red, Colors.purple, Colors.blue, Colors.green, Colors.orange];

final _quickIcons = [
  defaultGroupIcon,
  ...[
    'memory',
    'newspaper',
    'sports_soccer',
    'photo_camera',
    'palette',
    'science',
    'music_note',
    'sports_esports',
    'public',
    'restaurant',
  ].map((key) => jsonEncode({'pack': 'material', 'key': key})),
];

/// The group's icon on its color. A small pencil badge says it can be changed.
class AppearanceButton extends StatelessWidget {
  final GroupTone tone;
  final String icon;
  final VoidCallback onPressed;

  const AppearanceButton({super.key, required this.tone, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = BorderRadius.circular(18);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Tooltip(
          message: L10n.of(context).color_and_icon,
          child: Material(
            color: tone.background,
            borderRadius: shape,
            child: InkWell(
              borderRadius: shape,
              onTap: onPressed,
              child: SizedBox.square(
                dimension: 56,
                child: Icon(deserializeIconData(icon), size: 28, color: tone.foreground),
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: -4,
          bottom: -4,
          child: IgnorePointer(
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: Icon(Icons.edit_outlined, size: 14, color: colors.onSurfaceVariant),
            ),
          ),
        ),
      ],
    );
  }
}

void openAppearanceSheet(BuildContext context, GroupEditorModel model) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => ScopedBuilder<GroupEditorModel, GroupEditorState?>(
    store: model,
    onState: (context, state) => state == null ? const SizedBox.shrink() : _AppearanceSheet(model: model, state: state),
  ),
);

class _AppearanceSheet extends StatelessWidget {
  final GroupEditorModel model;
  final GroupEditorState state;

  const _AppearanceSheet({required this.model, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(l10n.color),
          _ColorChoices(
            selected: state.draft.color,
            showsAll: state.showsAllColors,
            onPicked: model.pickColor,
            onMore: model.showAllColors,
          ),
          const SizedBox(height: 16),
          _Label(l10n.icon),
          _IconChoices(
            selected: state.draft.icon,
            tone: groupTone(context, state.draft.color),
            onPicked: model.pickIcon,
          ),
        ],
      ),
    );
  }
}

const _colorColumns = 7;
const _colorDotSize = 44.0;
const _iconColumns = 6;
const _iconTileSize = 48.0;
const _iconTileRadius = 14.0;

Widget _choiceGrid(int columns, List<Widget> children) => GridView.count(
  crossAxisCount: columns,
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  padding: EdgeInsets.zero,
  mainAxisSpacing: 4,
  children: children.map((child) => Center(child: child)).toList(),
);

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    );
  }
}

class _ColorChoices extends StatelessWidget {
  final Color? selected;
  final bool showsAll;
  final ValueChanged<Color?> onPicked;
  final VoidCallback onMore;

  const _ColorChoices({required this.selected, required this.showsAll, required this.onPicked, required this.onMore});

  bool _isSelected(Color? color) => color?.toARGB32() == selected?.toARGB32();

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final choices = showsAll
        ? [if (!_palette.any(_isSelected)) selected, ..._palette]
        : _withSelectedFirst(_quickColors, selected, _isSelected);
    return _choiceGrid(_colorColumns, [
      ...choices.map(
        (color) => _ColorDot(
          color: color,
          label: _colorLabel(l10n, color),
          selected: _isSelected(color),
          onTap: () => onPicked(color),
        ),
      ),
      if (!showsAll)
        _MoreChoicesButton(
          tooltip: l10n.more_colors,
          icon: Icons.add,
          shape: const CircleBorder(),
          size: _colorDotSize,
          onPressed: onMore,
        ),
    ]);
  }
}

class _ColorDot extends StatelessWidget {
  final Color? color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({required this.color, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tone = groupTone(context, color);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: _colorDotSize,
          height: _colorDotSize,
          decoration: BoxDecoration(
            color: tone.background,
            shape: BoxShape.circle,
            border: Border.all(color: selected ? tone.foreground : Colors.transparent, width: 2),
          ),
          child: selected ? Icon(Icons.check, size: 20, color: tone.foreground) : null,
        ),
      ),
    );
  }
}

class _IconChoices extends StatelessWidget {
  final String selected;
  final GroupTone tone;
  final ValueChanged<String> onPicked;

  const _IconChoices({required this.selected, required this.tone, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final icons = _withSelectedFirst(_quickIcons, selected, (icon) => icon == selected);
    return _choiceGrid(_iconColumns, [
      ...icons.indexed.map((entry) {
        final (index, icon) = entry;
        final isSelected = icon == selected;
        return IconButton(
          isSelected: isSelected,
          style: IconButton.styleFrom(
            backgroundColor: isSelected ? tone.background : colors.surfaceContainerHigh,
            foregroundColor: isSelected ? tone.foreground : colors.onSurfaceVariant,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_iconTileRadius)),
            fixedSize: const Size.square(_iconTileSize),
          ),
          icon: Icon(deserializeIconData(icon), semanticLabel: L10n.of(context).icon_number(index + 1)),
          onPressed: () => onPicked(icon),
        );
      }),
      _PickAnotherIcon(selected: selected, tone: tone, onPicked: onPicked),
    ]);
  }
}

/// Opens the picker of every Material icon.
class _PickAnotherIcon extends StatelessWidget {
  final String selected;
  final GroupTone tone;
  final ValueChanged<String> onPicked;

  const _PickAnotherIcon({required this.selected, required this.tone, required this.onPicked});

  Future<void> _pick(BuildContext context) async {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final icon = await showIconPicker(
      context,
      configuration: SinglePickerConfiguration(
        iconPackModes: [IconPack.material],
        preSelected: _decodePickerIcon(selected),
        title: Text(l10n.icon, style: theme.textTheme.headlineSmall),
        closeChild: Text(l10n.close, style: TextStyle(color: theme.colorScheme.primary)),
        searchHintText: l10n.search,
        noResultsText: l10n.no_results_for,
        iconPickerShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        iconSize: 38,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        iconBuilder: (context, icon, isSelected, onTap) => _PickerIcon(
          icon: icon,
          selected: isSelected,
          tone: tone,
          onTap: () => onTap(icon, onSelected: () => Navigator.pop(context, icon)),
        ),
      ),
    );
    if (icon != null) {
      onPicked(jsonEncode(serializeIcon(icon)));
    }
  }

  @override
  Widget build(BuildContext context) {
    // The icon picker uses Flutter's own material library, so it needs its own theme
    return fm.Theme(
      data: _pickerTheme(Theme.of(context)),
      child: Builder(
        builder: (themed) => _MoreChoicesButton(
          tooltip: L10n.of(context).pick_an_icon,
          icon: Icons.more_horiz,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_iconTileRadius)),
          size: _iconTileSize,
          onPressed: () => _pick(themed),
        ),
      ),
    );
  }
}

/// The outlined button that ends a grid of choices, to see more of them.
class _MoreChoicesButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final OutlinedBorder shape;
  final double size;
  final VoidCallback onPressed;

  const _MoreChoicesButton({
    required this.tooltip,
    required this.icon,
    required this.shape,
    required this.size,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: colors.primary,
        shape: shape.copyWith(side: BorderSide(color: colors.outlineVariant)),
        fixedSize: Size.square(size),
      ),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}

/// A choice that is not among [choices] takes the first place, and the grid keeps its size.
List<T> _withSelectedFirst<T>(List<T> choices, T selected, bool Function(T) isSelected) =>
    choices.any(isSelected) ? choices : [selected, ...choices.take(choices.length - 1)];

String _colorLabel(L10n l10n, Color? color) {
  if (color == null) {
    return l10n.default_color;
  }
  final index = _palette.indexWhere((choice) => choice?.toARGB32() == color.toARGB32());
  return index < 0 ? l10n.color : l10n.color_number(index);
}

IconPickerIcon? _decodePickerIcon(String serialized) {
  try {
    return deserializeIcon(Map<String, dynamic>.from(jsonDecode(serialized) as Map));
  } catch (_) {
    return null;
  }
}

class _PickerIcon extends StatelessWidget {
  final IconPickerIcon icon;
  final bool selected;
  final GroupTone tone;
  final VoidCallback onTap;

  const _PickerIcon({required this.icon, required this.selected, required this.tone, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? tone.background : Colors.transparent,
      borderRadius: BorderRadius.circular(_iconTileRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Icon(
          icon.data,
          size: 26,
          semanticLabel: icon.name.replaceAll('_', ' '),
          color: selected ? tone.foreground : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

fm.ThemeData _pickerTheme(ThemeData theme) {
  final colors = theme.colorScheme;
  return fm.ThemeData(
    colorScheme: fm.ColorScheme.fromSeed(seedColor: colors.primary, brightness: theme.brightness),
    inputDecorationTheme: fm.InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest,
      border: fm.OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
    ),
  );
}
