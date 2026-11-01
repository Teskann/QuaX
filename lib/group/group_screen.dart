import 'package:crypto/crypto.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/_feed.dart';
import 'package:quax/group/_feed_shell.dart';
import 'package:quax/group/feed_scroll_controller.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/search_query.dart';
import 'package:quax/ui/errors.dart';
import 'package:provider/provider.dart';
import 'package:quax/utils/iterables.dart';

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
  late final FeedScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = FeedScrollController();
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
      onLoading: (_) => const Center(child: CircularProgressIndicator()),
      onError: (_, error) =>
          ScaffoldErrorWidget(error: error, stackTrace: null, prefix: (l10n) => l10n.unable_to_load_the_group),
      onState: (_, group) {
        // TODO: This is pretty gross. Figure out how to have a "no data" state
        if (group.id.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return SubscriptionGroupFeed(
          group: group,
          chunks: feedChunksOf(group),
          includeReplies: group.includeReplies,
          includeRetweets: group.includeRetweets,
        );
      },
    );
  }
}

// Split the users into chunks, oldest first, to prevent thrashing of all groups when a new user is added
List<SubscriptionGroupFeedChunk> feedChunksOf(SubscriptionGroupGet group) {
  final users = group.feedSubscriptions.sorted((a, b) => a.createdAt.compareTo(b.createdAt)).toList();
  return packFeedChunks(users, includeReplies: group.includeReplies, includeRetweets: group.includeRetweets)
      .map((e) => SubscriptionGroupFeedChunk(e, group.includeReplies, group.includeRetweets))
      .toList();
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
  final FeedScrollController scrollController;
  final String id;
  final String name;
  final List<Widget>? actions;

  const SubscriptionGroupScreen(
      {super.key,
      required this.scrollController,
      required this.id,
      required this.name,
      this.actions});

  @override
  Widget build(BuildContext context) {
    return GroupFeedShell(
      scrollController: scrollController,
      groupId: id,
      titleBuilder: (context) => Text(name),
      bodyBuilder: (context) => SubscriptionGroupScreenContent(id: id),
      actionsBuilder: (context) => defaultGroupActions(
        context,
        model: context.read<GroupModel>(),
        scrollToTopController: scrollController,
        extra: actions ?? const [],
      ),
    );
  }
}
