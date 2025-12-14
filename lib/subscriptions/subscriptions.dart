import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/_groups.dart';
import 'package:quax/subscriptions/_import.dart';
import 'package:quax/subscriptions/_list.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:provider/provider.dart';

class SubscriptionsScreen extends StatelessWidget {
  final ScrollController scrollController;

  const SubscriptionsScreen({super.key, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.current.subscriptions),
        actions: [
          IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                Navigator.pushNamed(context, routeSettings);
              })
        ],
      ),
      body: Padding(
          padding: EdgeInsets.all(8.0),
          child: ListView(
            controller: scrollController,
            children: [
              ExpansionTile(
                title: Text(
                  L10n.of(context).groups,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                enabled: false,
                initiallyExpanded: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.add,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onPressed: () => openSubscriptionGroupDialog(context, null, '', defaultGroupIcon),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.sort,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'name',
                          child: Text(L10n.of(context).name),
                        ),
                        PopupMenuItem(
                          value: 'created_at',
                          child: Text(L10n.of(context).date_created),
                        ),
                      ],
                      onSelected: (value) => context.read<GroupsModel>().changeOrderSubscriptionGroupsBy(value),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.sort_by_alpha,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onPressed: () => context.read<GroupsModel>().toggleOrderSubscriptionGroupsAscending(),
                    ),
                  ],
                ),
                children: [
                  SubscriptionGroups(
                    scrollController: scrollController,
                  ),
                ],
              ),
              const SizedBox(
                height: 8.0,
              ),
              ExpansionTile(
                title: Text(
                  L10n.of(context).subscriptions,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                enabled: false,
                initiallyExpanded: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.cloud_download,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionImportScreen()),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.refresh,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onPressed: () => context.read<SubscriptionsModel>().refreshSubscriptionData(),
                    ),
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.sort,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'name',
                          child: Text(L10n.of(context).name),
                        ),
                        PopupMenuItem(
                          value: 'screen_name',
                          child: Text(L10n.of(context).username),
                        ),
                        PopupMenuItem(
                          value: 'created_at',
                          child: Text(L10n.of(context).date_subscribed),
                        ),
                      ],
                      onSelected: (value) => context.read<SubscriptionsModel>().changeOrderSubscriptionsBy(value),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.sort_by_alpha,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      onPressed: () => context.read<SubscriptionsModel>().toggleOrderSubscriptionsAscending(),
                    ),
                  ],
                ),
                children: [
                  SubscriptionUsers(
                    scrollController: scrollController,
                  )
                ],
              ),
            ],
          )),
    );
  }
}
