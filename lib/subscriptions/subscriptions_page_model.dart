import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/subscription_filters.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/subscription_order.dart';

class SubscriptionsPageState {
  /// Null while the search bar is closed.
  final String? query;

  /// Null shows every kind.
  final SubscriptionKind? kind;

  final Set<SubscriptionRef> selected;

  final bool groupsCollapsed;

  const SubscriptionsPageState({this.query, this.kind, this.selected = const {}, this.groupsCollapsed = false});

  bool get searching => query != null;

  bool get selecting => selected.isNotEmpty;

  String get normalizedQuery => normalizeQuery(query);

  SubscriptionsPageState copyWith({
    String? Function()? query,
    SubscriptionKind? Function()? kind,
    Set<SubscriptionRef>? selected,
    bool? groupsCollapsed,
  }) => SubscriptionsPageState(
    query: query == null ? this.query : query(),
    kind: kind == null ? this.kind : kind(),
    selected: selected ?? this.selected,
    groupsCollapsed: groupsCollapsed ?? this.groupsCollapsed,
  );
}

class SubscriptionsPageModel extends Store<SubscriptionsPageState> {
  final BasePrefService prefs;

  SubscriptionsPageModel(this.prefs)
    : super(SubscriptionsPageState(groupsCollapsed: prefs.get(optionSubscriptionGroupsCollapsed) ?? false));

  void openSearch() => update(state.copyWith(query: () => ''));

  void closeSearch() => update(state.copyWith(query: () => null));

  void search(String query) => update(state.copyWith(query: () => query));

  /// Clears the selection, which could hold subscriptions the new filter hides.
  void showKind(SubscriptionKind? kind) => update(state.copyWith(kind: () => kind, selected: const {}));

  void toggleSelected(Subscription subscription) {
    final ref = SubscriptionRef.of(subscription);
    final selected = state.selected.contains(ref)
        ? state.selected.where((r) => r != ref).toSet()
        : {...state.selected, ref};
    update(state.copyWith(selected: selected));
  }

  void clearSelection() => update(state.copyWith(selected: const {}));

  Future<void> toggleGroupsCollapsed() async {
    final collapsed = !state.groupsCollapsed;
    update(state.copyWith(groupsCollapsed: collapsed));
    await prefs.set(optionSubscriptionGroupsCollapsed, collapsed);
  }
}

/// What the subscriptions page shows, worked out from its state and what is stored.
class SubscriptionsView {
  /// The subscriptions matching the search, whatever their kind.
  final List<Subscription> matching;

  /// The subscriptions listed: those of [matching] of the chosen kind.
  final List<Subscription> shown;

  /// The groups shown: all of them, or while searching those that match.
  final List<SubscriptionGroup> groups;
  final Map<SubscriptionRef, List<SubscriptionGroup>> groupsOfSubscription;
  final SubscriptionOrder order;
  final bool showsGroupsSection;
  final bool groupsExpanded;

  /// Dragging works in the custom order only, with the whole list shown and nothing selected.
  final bool canReorder;

  /// When other filters hold matches of the search, their chips already say so.
  final bool showsEmptyState;

  const SubscriptionsView._({
    required this.matching,
    required this.shown,
    required this.groups,
    required this.groupsOfSubscription,
    required this.order,
    required this.showsGroupsSection,
    required this.groupsExpanded,
    required this.canReorder,
    required this.showsEmptyState,
  });

  factory SubscriptionsView.of(
    SubscriptionsPageState page,
    List<Subscription> subscriptions,
    List<SubscriptionGroup> groups,
    Map<String, Set<SubscriptionRef>> members,
    SubscriptionOrder order,
  ) {
    final (:matching, :shown) = filterSubscriptions(subscriptions, page.normalizedQuery, page.kind);
    final matchingGroups = groupsMatchingSearch(groups, members, matching, page.normalizedQuery);
    return SubscriptionsView._(
      matching: matching,
      shown: shown,
      groups: matchingGroups,
      groupsOfSubscription: groupsBySubscription(groups, members),
      order: order,
      showsGroupsSection: !page.searching || matchingGroups.isNotEmpty,
      // Groups matching a search show even when the section is collapsed
      groupsExpanded: page.searching || !page.groupsCollapsed,
      canReorder: order.sort == SubscriptionSort.custom && !page.selecting && !page.searching && shown.length > 1,
      showsEmptyState: shown.isEmpty && (page.normalizedQuery.isEmpty || matching.isEmpty),
    );
  }
}
