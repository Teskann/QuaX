import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';

/// Opens the filters of a search, with the number of filters set in a badge.
class SearchFiltersButton extends StatelessWidget {
  final int count;
  final VoidCallback onPressed;

  const SearchFiltersButton({super.key, required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: L10n.of(context).search_filters_button(count),
      onPressed: onPressed,
      icon: Badge(
        isLabelVisible: count > 0,
        backgroundColor: colors.primary,
        textColor: colors.onPrimary,
        label: ExcludeSemantics(child: Text('$count')),
        child: const Icon(Icons.tune),
      ),
    );
  }
}
