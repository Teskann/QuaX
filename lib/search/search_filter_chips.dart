import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/search/search_filter_labels.dart';
import 'package:quax/search/search_filters.dart';

/// The active filters of a search, each removable from its chip.
class SearchFilterChips extends StatelessWidget {
  final SearchFilters filters;
  final ValueChanged<ActiveFilter> onRemoved;
  final VoidCallback onTap;

  const SearchFilterChips({super.key, required this.filters, required this.onRemoved, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final active = filters.active;

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 8,
          children: active
              .map(
                (filter) => InputChip(
                  label: Text(activeFilterLabel(l10n, filter)),
                  onPressed: onTap,
                  onDeleted: () => onRemoved(filter),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
