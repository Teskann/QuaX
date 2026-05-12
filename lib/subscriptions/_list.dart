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
  final ScrollController scrollController;

  const SubscriptionUsers({super.key, required this.scrollController});

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
                child: Text(message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                    )),
              ),
            ]));
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

  Widget _buildFilteredList(BuildContext context, List<Subscription> state, String query) {
    final filtered = state
        .where((s) => s.name.toLowerCase().contains(query) || s.screenName.toLowerCase().contains(query))
        .toList();
    if (filtered.isEmpty) {
      return _buildPlaceholder(context, L10n.of(context).no_results);
    }
    return ListView.builder(
      shrinkWrap: true,
      controller: widget.scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, i) => buildSubscriptionTile(context, filtered[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    var model = context.read<SubscriptionsModel>();

    return ScopedBuilder<SubscriptionsModel, List<Subscription>>.transition(
      store: model,
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (_, e) =>
          FullPageErrorWidget(error: e, stackTrace: null, prefix: L10n.of(context).unable_to_refresh_the_subscriptions),
      onState: (_, state) {
        if (state.isEmpty) {
          return _buildPlaceholder(context, L10n.of(context).no_subscriptions_try_searching_or_importing_some);
        }
        final query = _searchController.text.toLowerCase();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchBar(context),
            if (query.isEmpty)
              SubscriptionUsersList(
                subscriptions: state,
                scrollController: widget.scrollController,
              )
            else
              _buildFilteredList(context, state, query),
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
      Navigator.pushNamed(context, routeSearch,
          arguments: SearchArguments(0, focusInputOnOpen: false, query: user.id));
    },
  );
}

class SubscriptionUsersList extends StatelessWidget {
  final ScrollController scrollController;
  final List<Subscription> subscriptions;

  const SubscriptionUsersList({super.key, required this.subscriptions, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    BasePrefService prefs = PrefService.of(context);
    String subscriptionOrderCustom = prefs.get(optionSubscriptionOrderCustom);
    List<Subscription> subLst = [];
    if (subscriptionOrderCustom.isNotEmpty) {
      subLst
          .addAll(subscriptionOrderCustom.split(',').map((sn) => subscriptions.firstWhere((s) => s.screenName == sn)));
    } else {
      subLst.addAll(subscriptions);
    }
    return ReorderableListView.builder(
        shrinkWrap: true,
        scrollController: scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: subLst.length,
        itemBuilder: (context, i) => buildSubscriptionTile(context, subLst[i]),
        onReorder: (oldIndex, newIndex) async {
          if (oldIndex < newIndex) {
            Subscription s = subLst.removeAt(oldIndex);
            subLst.insert(newIndex - 1, s);
          } else {
            Subscription s = subLst.removeAt(oldIndex);
            subLst.insert(newIndex, s);
          }
          final lst = subLst.map((s) => s.screenName).join(',');
          await PrefService.of(context).set(optionSubscriptionOrderCustom, lst);
        });
  }
}
