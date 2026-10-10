import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/_for_you.dart';
import 'package:quax/home/_x_feed.dart';
import 'package:quax/home/_x_feed_header.dart';
import 'package:quax/home/_x_timelines.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/_feed_shell.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';

typedef FeedTabTitleBuilder = String Function(BuildContext context);

enum FeedTab { following, foryou }

class FeedTabOption {
  final FeedTab id;
  final FeedTabTitleBuilder titleBuilder;

  FeedTabOption(this.id, this.titleBuilder);
}

final List<FeedTabOption> feedTabs = [
  FeedTabOption(FeedTab.following, (c) => L10n.of(c).following),
  FeedTabOption(FeedTab.foryou, (c) => L10n.of(c).foryou),
];

FeedTab feedTabFromId(String? id) =>
    FeedTab.values.firstWhere((e) => e.name == id, orElse: () => FeedTab.following);

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
  FeedTab? _tab;

  Widget _buildXBody(BuildContext context, XFeedTab tab, BasePrefService prefs) => switch (tab.kind) {
        XFeedTabKind.forYou => ForYouTweets(_feedController, type: 'profile', includeReplies: false, pref: prefs),
        XFeedTabKind.following => SubscriptionGroupScreenContent(id: widget.id, cacheKey: tab.cacheKey),
        XFeedTabKind.group => SubscriptionGroupScreenContent(id: tab.group!.id, cacheKey: tab.cacheKey),
        XFeedTabKind.add => XAddTimelinesPage(onAdd: () => showCreateTimelineSheet(context)),
      };

  @override
  Widget build(BuildContext context) {
    final BasePrefService prefs = PrefService.of(context);
    final tab = _tab ??= feedTabFromId(prefs.get<String>(optionHomeDefaultFeedTab));

    if (isXStyle(context)) {
      return XFeedScreen(
        scrollController: widget.scrollController,
        id: widget.id,
        initialKind: tab == FeedTab.foryou ? XFeedTabKind.forYou : XFeedTabKind.following,
        bodyBuilder: (context, xTab) => _buildXBody(context, xTab, prefs),
      );
    }

    return GroupFeedShell(
      scrollController: widget.scrollController,
      groupId: widget.id,
      titleBuilder: (context) => DropdownMenu<FeedTab>(
        initialSelection: tab,
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
        ),
        dropdownMenuEntries:
            feedTabs.map((e) => DropdownMenuEntry(value: e.id, label: e.titleBuilder(context))).toList(),
        onSelected: (value) {
          setState(() => _tab = value!);
        },
      ),
      actionsBuilder: (context) {
        final model = context.read<GroupModel>();
        return defaultGroupActions(
          context,
          model: model,
          showMore: tab == FeedTab.following,
        );
      },
      bodyBuilder: (context) {
        if (tab == FeedTab.following) {
          return SubscriptionGroupScreenContent(id: widget.id);
        }
        return ForYouTweets(_feedController, type: 'profile', includeReplies: false, pref: prefs);
      },
    );
  }
}
