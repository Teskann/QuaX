import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/_feed.dart';
import 'package:quax/group/_settings.dart';
import 'package:quax/ui/errors.dart';
import 'package:provider/provider.dart';
import 'package:quax/utils/iterables.dart';
import 'package:quiver/iterables.dart';

class GroupScreenArguments {
  final String id;
  final String name;

  GroupScreenArguments({required this.id, required this.name});

  @override
  String toString() {
    return 'GroupScreenArguments{id: $id, name: $name}';
  }
}

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as GroupScreenArguments;
    return SubscriptionGroupScreen(
      scrollController: _scrollController,
      id: args.id,
      name: args.name,
      actions: const [],
    );
  }
}

class SubscriptionGroupScreenContent extends StatelessWidget {
  final String id;

  const SubscriptionGroupScreenContent({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<GroupModel, SubscriptionGroupGet>.transition(
      store: context.read<GroupModel>(),
      onLoading: (_) => const Center(child: Text('lad')),
      onError: (_, error) =>
          ScaffoldErrorWidget(error: error, stackTrace: null, prefix: L10n.current.unable_to_load_the_group),
      onState: (_, group) {
        // TODO: This is pretty gross. Figure out how to have a "no data" state
        if (group.id.isEmpty) {
          return Container();
        }

        // Split the users into chunks, oldest first, to prevent thrashing of all groups when a new user is added
        var users = group.subscriptions.sorted((a, b) => a.createdAt.compareTo(b.createdAt)).toList();

        var chunks = partition(users, 16)
            .map((e) => SubscriptionGroupFeedChunk(e, group.includeReplies, group.includeRetweets))
            .toList();

        return SubscriptionGroupFeed(
          group: group,
          chunks: chunks,
          includeReplies: group.includeReplies,
          includeRetweets: group.includeRetweets,
        );
      },
    );
  }
}

class SubscriptionGroupFeedChunk {
  final List<Subscription> users;
  final bool includeReplies;
  final bool includeRetweets;

  SubscriptionGroupFeedChunk(this.users, this.includeReplies, this.includeRetweets);

  String get hash {
    var toHash = '${users.map((e) => e.id).join(', ')}$includeReplies$includeRetweets';

    return sha1.convert(toHash.codeUnits).toString();
  }
}

class SubscriptionGroupScreen extends StatelessWidget {
  final ScrollController scrollController;
  final String id;
  final String name;
  final List<Widget>? actions;

  const SubscriptionGroupScreen(
      {super.key, required this.scrollController, required this.id, required this.name, this.actions});

  @override
  Widget build(BuildContext context) {
    return Provider<GroupModel>(
      create: (context) {
        var model = GroupModel(id);
        model.loadGroup();

        return model;
      },
      builder: (context, child) {
        var model = context.read<GroupModel>();

        return NestedScrollView(
          controller: scrollController,
          floatHeaderSlivers: true,
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: false,
                snap: true,
                floating: true,
                title: Text(name),
                actions: [
                  IconButton(icon: const Icon(Icons.more_vert), onPressed: () => showFeedSettings(context, model)),
                  IconButton(
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () async {
                        await scrollController.animateTo(0,
                            duration: PrefService.of(context).get(optionDisableAnimations) == true
                                ? Duration.zero
                                : const Duration(seconds: 1),
                            curve: Curves.easeInOut);
                      }),
                  IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: () async {
                        await model.loadGroup();
                      }),
                  IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () async {
                        Navigator.pushNamed(context, routeSettings);
                      }),
                  if (actions != null) ...actions!
                ],
              )
            ];
          },
          body: SubscriptionGroupScreenContent(id: id),
        );
      },
    );
  }
}
