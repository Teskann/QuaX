import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/_feed_shell.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/_x_feed_header.dart';

typedef XFeedBodyBuilder = Widget Function(BuildContext context, XFeedTab tab);

/// The home feed of the X design: a header with one tab per timeline (For you, Following, the groups, and "add").
/// What each tab shows is up to [bodyBuilder].
class XFeedScreen extends StatefulWidget {
  final ScrollController scrollController;

  /// The id of the group behind the Following tab
  final String id;
  final XFeedTabKind initialKind;
  final XFeedBodyBuilder bodyBuilder;

  const XFeedScreen({
    super.key,
    required this.scrollController,
    required this.id,
    required this.initialKind,
    required this.bodyBuilder,
  });

  @override
  State<XFeedScreen> createState() => _XFeedScreenState();
}

class _XFeedScreenState extends State<XFeedScreen> with TickerProviderStateMixin {
  late List<XFeedTab> _tabs;
  late TabController _controller;
  late final Future<void> Function() _stopObservingGroups;

  @override
  void initState() {
    super.initState();
    final groups = context.read<GroupsModel>();
    _tabs = xFeedTabs(groups.state);
    _controller = _newController(max(0, _tabs.indexWhere((e) => e.kind == widget.initialKind)));
    _stopObservingGroups = groups.observer(onState: _onGroupsChanged);
  }

  TabController _newController(int index) => TabController(length: _tabs.length, initialIndex: index, vsync: this);

  void _onGroupsChanged(List<SubscriptionGroup> groups) {
    final selectedId = _tabs[_controller.index].id;
    final tabs = xFeedTabs(groups);
    final index = max(0, tabs.indexWhere((e) => e.id == selectedId));
    final old = _controller;
    final replaceController = tabs.length != old.length || index != old.index;
    setState(() {
      _tabs = tabs;
      if (replaceController) _controller = _newController(index);
    });
    if (replaceController) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void dispose() {
    _stopObservingGroups();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tab = _tabs[_controller.index];
    final groupId = tab.group?.id ?? widget.id;
    // Each group has its own shell, which holds the model its settings button edits
    return GroupFeedShell(
      key: ValueKey(groupId),
      scrollController: widget.scrollController,
      groupId: groupId,
      appBarBuilder: (_) => XFeedAppBar(tabs: _tabs, controller: _controller, onTabTap: () => setState(() {})),
      bodyBuilder: (context) => widget.bodyBuilder(context, tab),
    );
  }
}
