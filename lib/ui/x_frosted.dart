import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/ui/x_style.dart';

/// The translucent bars of the X design: the content scrolling underneath shows through, blurred. The blur is
/// GPU-expensive, so the bar turns opaque when the user disabled animations, and the bars below the same
/// [BackdropGroup] share one capture of what is behind them.
class XFrostedBar extends StatelessWidget {
  static const double opacity = 0.9;
  static const double sigma = 6;

  final Widget child;

  const XFrostedBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final background = XStyleColors.of(context).background;
    final disableAnimations = PrefService.of(context).get<bool>(optionDisableAnimations) ?? false;
    if (disableAnimations) {
      return ColoredBox(color: background, child: child);
    }
    return ClipRect(
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: ColoredBox(color: background.withValues(alpha: opacity), child: child),
      ),
    );
  }
}

/// The border that closes an app bar of the X design at the bottom.
ShapeBorder xBarBorder(BuildContext context) =>
    LinearBorder.bottom(side: BorderSide(color: XStyleColors.of(context).divider));
