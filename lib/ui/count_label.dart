import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ui/locale_fallback.dart';

/// A short form of [count] in the language of the app, as in 4.9K.
String formatCount(int count) => NumberFormat.compact(locale: formattingLocale()).format(count);

/// A number in bold, then what it counts, as in "42 Members".
class CountLabel extends StatelessWidget {
  final int count;
  final String label;

  /// Shows the number in the main color, to say that the label can be tapped.
  final bool tappable;

  const CountLabel({super.key, required this.count, required this.label, this.tappable = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatCount(count),
            style: TextStyle(fontWeight: FontWeight.bold, color: tappable ? theme.colorScheme.primary : null),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
      style: theme.textTheme.bodyMedium,
    );
  }
}
