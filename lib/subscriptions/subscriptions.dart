import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/search/search.dart';
import 'package:quax/subscriptions/_groups.dart';
import 'package:quax/subscriptions/_import.dart';
import 'package:quax/subscriptions/_list.dart';
import 'package:quax/subscriptions/_search_field.dart';
import 'package:quax/subscriptions/_selection.dart';
import 'package:quax/subscriptions/subscription_display.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/subscription_order.dart';
import 'package:quax/subscriptions/subscription_order_store.dart';
import 'package:quax/subscriptions/subscriptions_page_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/back_interceptors.dart';
import 'package:quax/ui/errors.dart';

/// The id of the subscriptions page among the pages of the home screen.
const subscriptionsPageId = 'subscriptions';

class SubscriptionsScreen extends StatefulWidget {
  final ScrollController scrollController;

  const SubscriptionsScreen({super.key, required this.scrollController});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late final SubscriptionsPageModel _pageModel = SubscriptionsPageModel(PrefService.of(context, listen: false));
  late final BackInterceptors _backInterceptors = context.read<BackInterceptors>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _backInterceptors.add(subscriptionsPageId, _onBack);
  }

  @override
  void dispose() {
    _backInterceptors.remove(subscriptionsPageId);
    _searchController.dispose();
    _pageModel.destroy();
    super.dispose();
  }

  bool _onBack() {
    if (_pageModel.state.selecting) {
      _pageModel.clearSelection();
      return true;
    }
    if (_pageModel.state.searching) {
      _closeSearch();
      return true;
    }
    return false;
  }

  void _closeSearch() {
    _searchController.clear();
    _pageModel.closeSearch();
  }

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<SubscriptionsModel, List<Subscription>>(
      store: context.read<SubscriptionsModel>(),
      onError: (_, e) => Scaffold(
        body: FullPageErrorWidget(
          error: e,
          stackTrace: null,
          prefix: (l10n) => l10n.unable_to_refresh_the_subscriptions,
        ),
      ),
      onState: (_, subscriptions) => ScopedBuilder<SubscriptionsPageModel, SubscriptionsPageState>(
        store: _pageModel,
        onState: (_, page) => Scaffold(
          appBar: _appBar(context, page, subscriptions),
          body: _SubscriptionsBody(
            pageModel: _pageModel,
            page: page,
            subscriptions: subscriptions,
            scrollController: widget.scrollController,
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, SubscriptionsPageState page, List<Subscription> subscriptions) {
    final l10n = L10n.of(context);
    if (page.selecting) {
      final selected = subscriptions.where((s) => page.selected.contains(SubscriptionRef.of(s))).toList();
      return SelectionAppBar(selected: selected, onClear: _pageModel.clearSelection);
    }
    final settings = IconButton(
      icon: const Icon(Icons.settings),
      tooltip: l10n.settings,
      onPressed: () => Navigator.pushNamed(context, routeSettings),
    );
    if (page.searching) {
      return AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), tooltip: l10n.close, onPressed: _closeSearch),
        titleSpacing: 0,
        title: CompactSearchField(controller: _searchController, onChanged: _pageModel.search, autofocus: true),
        actions: [settings],
      );
    }
    return AppBar(
      title: Text(l10n.subscriptions),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: l10n.search_your_subscriptions,
          onPressed: _pageModel.openSearch,
        ),
        IconButton(
          icon: const Icon(Icons.input),
          tooltip: l10n.import_subscriptions,
          onPressed: () => openImport(context),
        ),
        settings,
      ],
    );
  }
}

class _SubscriptionsBody extends StatelessWidget {
  final SubscriptionsPageModel pageModel;
  final SubscriptionsPageState page;
  final List<Subscription> subscriptions;
  final ScrollController scrollController;

  const _SubscriptionsBody({
    required this.pageModel,
    required this.page,
    required this.subscriptions,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final model = context.read<SubscriptionsModel>();
    return ScopedBuilder<GroupsModel, List<SubscriptionGroup>>(
      store: context.read<GroupsModel>(),
      onState: (_, groups) => ScopedBuilder<GroupMembershipsModel, Map<String, Set<SubscriptionRef>>>(
        store: context.read<GroupMembershipsModel>(),
        onState: (_, members) => ScopedBuilder<SubscriptionOrderStore, SubscriptionOrder>(
          store: model.order,
          onState: (_, order) => _content(context, SubscriptionsView.of(page, subscriptions, groups, members, order)),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, SubscriptionsView view) {
    return CustomScrollView(
      controller: scrollController,
      slivers: [
        if (view.showsGroupsSection) ...[
          SliverToBoxAdapter(
            child: GroupsHeader(collapsed: !view.groupsExpanded, onToggleCollapsed: pageModel.toggleGroupsCollapsed),
          ),
          if (view.groupsExpanded) SliverToBoxAdapter(child: GroupsGrid(groups: view.groups)),
        ],
        SliverToBoxAdapter(child: _listHeader(context, view.order)),
        if (view.matching.isNotEmpty)
          SliverToBoxAdapter(
            child: KindFilters(subscriptions: view.matching, chosen: page.kind, onChosen: pageModel.showKind),
          ),
        if (view.showsEmptyState) SliverToBoxAdapter(child: _emptyState(context)) else _rows(context, view),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 16)),
      ],
    );
  }

  Widget _listHeader(BuildContext context, SubscriptionOrder order) {
    final model = context.read<SubscriptionsModel>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
      child: Row(
        children: [
          Expanded(child: SectionTitle(L10n.of(context).followed)),
          SortControls(order: order, onNextSort: model.showNextSort, onReverse: model.reverseOrder),
        ],
      ),
    );
  }

  Widget _rows(BuildContext context, SubscriptionsView view) {
    final model = context.read<SubscriptionsModel>();
    final shown = view.shown;
    final canReorder = view.canReorder;
    Widget row(int index) {
      final subscription = shown[index];
      final ref = SubscriptionRef.of(subscription);
      return SubscriptionRow(
        key: ValueKey(ref),
        subscription: subscription,
        groups: view.groupsOfSubscription[ref] ?? const [],
        selected: page.selected.contains(ref),
        selecting: page.selecting,
        onToggleSelected: () => pageModel.toggleSelected(subscription),
        reorderIndex: canReorder ? index : null,
        onMoveUp: canReorder && index > 0 ? () => model.moveSubscription(shown, index, index - 1) : null,
        onMoveDown: canReorder && index < shown.length - 1
            ? () => model.moveSubscription(shown, index, index + 1)
            : null,
      );
    }

    if (!canReorder) {
      return SliverList.builder(itemCount: shown.length, itemBuilder: (_, index) => row(index));
    }
    return SliverReorderableList(
      itemCount: shown.length,
      proxyDecorator: (child, _, _) => Material(type: MaterialType.transparency, child: child),
      itemBuilder: (_, index) => row(index),
      onReorderItem: (oldIndex, newIndex) => model.moveSubscription(shown, oldIndex, newIndex),
    );
  }

  Widget _emptyState(BuildContext context) {
    final l10n = L10n.of(context);
    final query = page.query?.trim() ?? '';
    if (query.isNotEmpty) {
      final tab = page.kind?.searchTab ?? SearchTab.top;
      return EmptySubscriptions(
        icon: Icons.search_off,
        message: l10n.no_subscription_matches(query),
        actionIcon: Icons.travel_explore,
        actionLabel: l10n.search_on_x(query),
        onAction: () => Navigator.pushNamed(context, routeSearch, arguments: SearchArguments(tab, query: query)),
      );
    }
    return switch (page.kind) {
      SubscriptionKind.user || null => EmptySubscriptions(
        icon: Icons.inbox_outlined,
        message: SubscriptionKind.user.emptyMessage(l10n),
        actionIcon: Icons.input,
        actionLabel: l10n.import_subscriptions,
        onAction: () => openImport(context),
      ),
      final kind => _searchToFollow(context, kind),
    };
  }

  /// Asks to search X for something to follow.
  Widget _searchToFollow(BuildContext context, SubscriptionKind kind) => EmptySubscriptions(
    icon: kind.icon,
    message: kind.emptyMessage(L10n.of(context)),
    actionIcon: Icons.search,
    actionLabel: L10n.of(context).search,
    onAction: () =>
        Navigator.pushNamed(context, routeSearch, arguments: SearchArguments(kind.searchTab, focusInputOnOpen: true)),
  );
}

void openImport(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionImportScreen()));
