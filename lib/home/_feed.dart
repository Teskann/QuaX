import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/home/_for_you.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/_feed_shell.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';

class FeedScreen extends StatefulWidget {
  final ScrollController scrollController;
  final String id;
  final String name;

  const FeedScreen({super.key, required this.scrollController, required this.id, required this.name});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final TweetFeedController _feedController = TweetFeedController();
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final BasePrefService prefs = PrefService.of(context);
    final l10n = L10n.of(context);

    return GroupFeedShell(
      scrollController: widget.scrollController,
      groupId: widget.id,
      titleBuilder: (context) => DropdownMenu(
        initialSelection: 0,
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        dropdownMenuEntries: [
          DropdownMenuEntry(value: 0, label: l10n.following),
          DropdownMenuEntry(value: 1, label: l10n.foryou),
        ],
        onSelected: (value) {
          setState(() => _tab = value!);
        },
      ),
      actionsBuilder: (context) {
        final model = context.read<GroupModel>();
        return defaultGroupActions(
          context,
          model: model,
          showMore: _tab == 0,
        );
      },
      bodyBuilder: (context) {
        if (_tab == 0) {
          return SubscriptionGroupScreenContent(id: widget.id);
        }
        return ForYouTweets(_feedController, type: 'profile', includeReplies: false, pref: prefs);
      },
    );
  }
}
