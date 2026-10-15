import 'package:material_ui/material_ui.dart';

/// Merges a preference toggle with its title, so that a screen reader names the switch it announces.
class LabeledPref extends StatelessWidget {
  final Widget child;

  const LabeledPref({super.key, required this.child});

  @override
  Widget build(BuildContext context) => MergeSemantics(child: child);
}
