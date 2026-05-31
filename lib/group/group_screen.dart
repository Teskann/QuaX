import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/_feed.dart';
import 'package:quax/group/_feed_shell.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/tweet/cached_tweet_list.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
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
      // Pushed routes persist their feed state across pop/push via the cache.
      // The cache key matches the groupId so re-pushing the same group restores
      // the previous tweets and scroll offset.
      cacheKey: args.id,
      actions: const [],
    );
  }
}

class SubscriptionGroupScreenContent extends StatefulWidget {
  final String id;
  final String? cacheKey;

  const SubscriptionGroupScreenContent({super.key, required this.id, this.cacheKey});

  @override
  State<SubscriptionGroupScreenContent> createState() => _SubscriptionGroupScreenContentState();
}

class _SubscriptionGroupScreenContentState extends State<SubscriptionGroupScreenContent> {
  // Cached tweets shown while the group's subscriptions load, so the feed
  // reveals its content instead of a full-screen spinner on cold start.
  List<TweetChain>? _preview;

  @override
  void initState() {
    super.initState();
    // Only the combined "All"/Following feed (id '-1') can preview every cached
    // chunk up front; a specific group needs its own chunk hashes (unknown until
    // loadGroup finishes) to avoid showing tweets from other groups.
    if (widget.id == '-1') {
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    var repository = await Repository.readOnly();
    var chains = await readAllCachedChains(repository);
    if (!mounted) return;
    setState(() => _preview = chains);
  }

  Widget _loadingView() {
    var preview = _preview;
    if (preview != null && preview.isNotEmpty) {
      return TweetContextScope(child: CachedTweetList(preview));
    }
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<GroupModel, SubscriptionGroupGet>.transition(
      store: context.read<GroupModel>(),
      onLoading: (_) => _loadingView(),
      onError: (_, error) =>
          ScaffoldErrorWidget(error: error, stackTrace: null, prefix: L10n.current.unable_to_load_the_group),
      onState: (_, group) {
        // TODO: This is pretty gross. Figure out how to have a "no data" state
        if (group.id.isEmpty) {
          return _loadingView();
        }
        // Split the users into chunks, oldest first, to prevent thrashing of all groups when a new user is added
        final filteredUsers = group.id == '-1' ? group.subscriptions.where((elm) => elm.inFeed) : group.subscriptions;
        final users = filteredUsers.sorted((a, b) => a.createdAt.compareTo(b.createdAt)).toList();

        var chunks = partition(users, 16)
            .map((e) => SubscriptionGroupFeedChunk(e, group.includeReplies, group.includeRetweets))
            .toList();

        return SubscriptionGroupFeed(
          group: group,
          chunks: chunks,
          includeReplies: group.includeReplies,
          includeRetweets: group.includeRetweets,
          cacheKey: widget.cacheKey,
          initialPreview: _preview,
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
  // Forwarded to SubscriptionGroupFeed — see its docs. Null disables caching.
  final String? cacheKey;

  const SubscriptionGroupScreen(
      {super.key,
      required this.scrollController,
      required this.id,
      required this.name,
      this.actions,
      this.cacheKey});

  @override
  Widget build(BuildContext context) {
    return GroupFeedShell(
      scrollController: scrollController,
      groupId: id,
      titleBuilder: (context) => Text(name),
      bodyBuilder: (context) => SubscriptionGroupScreenContent(id: id, cacheKey: cacheKey),
      actionsBuilder: (context) => defaultGroupActions(
        context,
        model: context.read<GroupModel>(),
        scrollToTopController: scrollController,
        extra: actions ?? const [],
      ),
    );
  }
}
