import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/search/search.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';

class SubscriptionUsers extends StatefulWidget {
  const SubscriptionUsers({super.key});

  @override
  State<SubscriptionUsers> createState() => _SubscriptionUsersState();
}

class _SubscriptionUsersState extends State<SubscriptionUsers> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildPlaceholder(BuildContext context, String message) {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: const Text('¯\\_(ツ)_/¯', style: TextStyle(fontSize: 32)),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).hintColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final hasQuery = _searchController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: SearchBar(
        controller: _searchController,
        hintText: L10n.of(context).search,
        leading: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.search),
        ),
        trailing: hasQuery
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              ]
            : null,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // Lazy, drag-to-reorder list shown when no search query is active.
  Widget _buildReorderableSliver(
    BuildContext context,
    List<Subscription> state,
  ) {
    final prefs = PrefService.of(context);
    final String orderCustom = prefs.get(optionSubscriptionOrderCustom);

    final subLst = <Subscription>[];
    if (orderCustom.isNotEmpty) {
      subLst.addAll(
        orderCustom
            .split(',')
            .map((sn) => state.firstWhere((s) => s.screenName == sn)),
      );
    } else {
      subLst.addAll(state);
    }

    return SliverReorderableList(
      itemCount: subLst.length,
      itemBuilder: (context, i) => ReorderableDelayedDragStartListener(
        key: ValueKey(subLst[i].screenName),
        index: i,
        child: buildSubscriptionTile(context, subLst[i]),
      ),
      onReorderItem: (oldIndex, newIndex) async {
        final s = subLst.removeAt(oldIndex);
        subLst.insert(newIndex, s);
        final lst = subLst.map((s) => s.screenName).join(',');
        await prefs.set(optionSubscriptionOrderCustom, lst);
      },
    );
  }

  // Lazy, filtered list shown while a search query is active.
  Widget _buildFilteredSliver(
    BuildContext context,
    List<Subscription> state,
    String query,
  ) {
    final filtered = state
        .where(
          (s) =>
              s.name.toLowerCase().contains(query) ||
              s.screenName.toLowerCase().contains(query),
        )
        .toList();
    if (filtered.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: _buildPlaceholder(context, L10n.of(context).no_results),
        ),
      );
    }
    return SliverList.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) => buildSubscriptionTile(context, filtered[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    var model = context.read<SubscriptionsModel>();

    return ScopedBuilder<SubscriptionsModel, List<Subscription>>(
      store: model,
      onLoading: (_) => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      onError: (_, e) => SliverFillRemaining(
        hasScrollBody: false,
        child: FullPageErrorWidget(
          error: e,
          stackTrace: null,
          prefix: L10n.of(context).unable_to_refresh_the_subscriptions,
        ),
      ),
      onState: (_, state) {
        if (state.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildPlaceholder(
              context,
              L10n.of(context).no_subscriptions_try_searching_or_importing_some,
            ),
          );
        }
        final query = _searchController.text.toLowerCase();
        return SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(child: _buildSearchBar(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              sliver: query.isEmpty
                  ? _buildReorderableSliver(context, state)
                  : _buildFilteredSliver(context, state, query),
            ),
          ],
        );
      },
    );
  }
}

Widget buildSubscriptionTile(BuildContext context, Subscription user) {
  if (user is UserSubscription) {
    return UserTile(key: Key(user.screenName), user: user);
  }

  return ListTile(
    key: Key(user.screenName),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
    leading: const SizedBox(width: 48, child: Icon(Icons.saved_search)),
    title: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(L10n.current.search_term),
    trailing: FollowButton(user: user),
    onTap: () {
      Navigator.pushNamed(
        context,
        routeSearch,
        arguments: SearchArguments(0, focusInputOnOpen: false, query: user.id),
      );
    },
  );
}
