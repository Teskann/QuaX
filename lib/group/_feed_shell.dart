import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/group/_settings.dart';
import 'package:quax/group/feed_refresh_controller.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/x_frosted.dart';
import 'package:quax/ui/x_overlay_feed.dart';
import 'package:quax/ui/x_style.dart';

class GroupFeedShell extends StatefulWidget {
  final ScrollController scrollController;
  final String groupId;
  final WidgetBuilder? titleBuilder;
  final WidgetBuilder bodyBuilder;
  final List<Widget> Function(BuildContext)? actionsBuilder;
  // Replaces the app bar and the NestedScrollView by a header laid over the body, which scrolls under it. The header
  // then ignores [titleBuilder] and [actionsBuilder].
  final WidgetBuilder? overlayHeaderBuilder;
  final double overlayHeaderHeight;

  const GroupFeedShell({
    super.key,
    required this.scrollController,
    required this.groupId,
    this.titleBuilder,
    required this.bodyBuilder,
    this.actionsBuilder,
    this.overlayHeaderBuilder,
    this.overlayHeaderHeight = 0,
  }) : assert(overlayHeaderBuilder != null || (titleBuilder != null && actionsBuilder != null));

  @override
  State<GroupFeedShell> createState() => _GroupFeedShellState();
}

class _GroupFeedShellState extends State<GroupFeedShell> with AutomaticKeepAliveClientMixin<GroupFeedShell> {
  late final GroupModel _groupModel;
  final FeedRefreshController _feedRefreshController = FeedRefreshController();
  int _refreshCounter = 0;
  // Cached refs captured in didChangeDependencies — accessing the InheritedWidget
  // tree via context.read in dispose() triggers a framework warning, since
  // ancestors may already be unmounted by then.
  SubscriptionsModel? _subscriptionsModel;
  GroupsModel? _groupsModel;

  late final String _callbackKey = 'GroupFeedShell-${widget.groupId}-${identityHashCode(this)}';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _groupModel = GroupModel(widget.groupId)..loadGroup();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newSubs = context.read<SubscriptionsModel>();
    final newGroups = context.read<GroupsModel>();
    if (!identical(newSubs, _subscriptionsModel) || !identical(newGroups, _groupsModel)) {
      _subscriptionsModel?.removeReloadListener(_callbackKey);
      _groupsModel?.removeReloadListener(_callbackKey);
      _subscriptionsModel = newSubs;
      _groupsModel = newGroups;
      _subscriptionsModel!.addReloadListener(_callbackKey, _onReload);
      _groupsModel!.addReloadListener(_callbackKey, _onReload);
    }
  }

  // Triggered when subscriptions or group memberships change. Refresh the group
  // state and bump the counter to remount the body — for pushed-route feeds
  // this drops the stale (cached, just-invalidated) PagingController so the
  // inner state re-fetches a fresh one from the cache.
  void _onReload() {
    if (!mounted) return;
    setState(() {
      _groupModel.loadGroup();
      _refreshCounter++;
    });
  }

  @override
  void dispose() {
    _subscriptionsModel?.removeReloadListener(_callbackKey);
    _groupsModel?.removeReloadListener(_callbackKey);
    super.dispose();
  }

  Widget _buildAppBar(BuildContext context) {
    final xStyle = isXStyle(context);
    return SliverAppBar(
      backgroundColor: xStyle ? Colors.transparent : Theme.of(context).colorScheme.surface,
      flexibleSpace: xStyle ? const XFrostedBar(child: SizedBox.expand()) : null,
      shape: xStyle ? xBarBorder(context) : null,
      pinned: false,
      snap: true,
      floating: true,
      title: widget.titleBuilder!(context),
      actions: widget.actionsBuilder!(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Provider<GroupModel>.value(
      value: _groupModel,
      builder: (context, child) {
        return Provider<FeedRefreshController>.value(
          value: _feedRefreshController,
          child: _buildScrollView(context),
        );
      },
    );
  }

  Widget _buildScrollView(BuildContext context) {
    final body = KeyedSubtree(
      key: ValueKey(_refreshCounter),
      child: widget.bodyBuilder(context),
    );
    final overlayHeaderBuilder = widget.overlayHeaderBuilder;
    if (overlayHeaderBuilder != null) {
      return XOverlayFeed(
        headerHeight: widget.overlayHeaderHeight,
        scrollController: widget.scrollController,
        header: overlayHeaderBuilder(context),
        body: body,
      );
    }
    return NestedScrollView(
      controller: widget.scrollController,
      floatHeaderSlivers: true,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          _buildAppBar(context),
        ];
      },
      body: body,
    );
  }
}

/// Builds the standard action-bar icons shared by group feeds:
/// optional "more" (group settings), optional "scroll-to-top", refresh, and
/// the global settings button.
List<Widget> defaultGroupActions(
  BuildContext context, {
  required GroupModel model,
  ScrollController? scrollToTopController,
  bool showMore = true,
  bool showRefresh = true,
  VoidCallback? onRefresh,
  List<Widget> extra = const [],
}) {
  return [
    if (showMore)
      IconButton(icon: const Icon(Icons.more_vert), onPressed: () => showFeedSettings(context, model)),
    if (scrollToTopController != null)
      IconButton(
          icon: const Icon(Icons.arrow_upward),
          onPressed: () async {
            final disableAnimations = PrefService.of(context).get(optionDisableAnimations) == true;
            await scrollToTopController.animateTo(0,
                duration: disableAnimations ? Duration.zero : const Duration(seconds: 1),
                curve: Curves.easeInOut);
          }),
    if (showRefresh)
      IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: onRefresh ?? () async => await context.read<FeedRefreshController>().refresh()),
    IconButton(
        icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, routeSettings)),
    ...extra,
  ];
}
