import 'package:material_ui/material_ui.dart';

/// Makes [child] as easy to tap as a button: at least as tall as one.
class TapArea extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const TapArea({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, child: child),
    ),
  );
}
