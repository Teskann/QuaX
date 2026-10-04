import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// A [TabBar] that also tells when the tab already shown is tapped again.
///
/// [TabBar.onTap] cannot tell it: the bar moves the controller before calling it, so the tapped tab always looks
/// selected. Here a tap is a reselection only when the controller did not change because of it.
class ReselectableTabBar extends StatefulWidget {
  final TabController controller;
  final List<Widget> tabs;
  final ValueChanged<int> onReselect;
  final Color? dividerColor;

  const ReselectableTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    required this.onReselect,
    this.dividerColor,
  });

  @override
  State<ReselectableTabBar> createState() => _ReselectableTabBarState();
}

class _ReselectableTabBarState extends State<ReselectableTabBar> {
  bool _changedJustNow = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChange);
  }

  @override
  void didUpdateWidget(ReselectableTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChange);
      widget.controller.addListener(_onControllerChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChange);
    super.dispose();
  }

  // The tap handler runs in the same call as the controller change, before this microtask clears the flag.
  void _onControllerChange() {
    _changedJustNow = true;
    scheduleMicrotask(() => _changedJustNow = false);
  }

  void _onTap(int index) {
    if (!_changedJustNow) widget.onReselect(index);
  }

  @override
  Widget build(BuildContext context) =>
      TabBar(controller: widget.controller, tabs: widget.tabs, onTap: _onTap, dividerColor: widget.dividerColor);
}
