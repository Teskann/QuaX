import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/_about.dart';
import 'package:quax/community/_header.dart';
import 'package:quax/community/community.dart';
import 'package:quax/community/community_model.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/timeline_pagination.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
import 'package:quax/ui/header_banner.dart';
import 'package:quax/ui/loaded_page.dart';

class CommunityScreenArguments {
  final String id;
  final bool showAbout;

  CommunityScreenArguments(this.id, {this.showAbout = false});
}

class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as CommunityScreenArguments;

    return LoadedPage<Community>(
      create: () => CommunityModel(args.id),
      errorPrefix: (l10n) => l10n.unable_to_load_the_community,
      builder: (_, community) => _CommunityBody(community: community, showAbout: args.showAbout),
    );
  }
}

class _CommunityBody extends StatefulWidget {
  final Community community;
  final bool showAbout;

  const _CommunityBody({required this.community, required this.showAbout});

  @override
  State<_CommunityBody> createState() => _CommunityBodyState();
}

class _CommunityBodyState extends State<_CommunityBody> {
  late final _top = TimelinePagination((cursor) => Twitter.getCommunityTweets(widget.community.id, cursor: cursor));

  @override
  void dispose() {
    _top.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.community;

    return DefaultTabController(
      length: 2,
      initialIndex: widget.showAbout ? 1 : 0,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          BannerAppBar(name: community.name, bannerUrl: community.bannerUrl, innerBoxIsScrolled: innerBoxIsScrolled),
          SliverToBoxAdapter(child: CommunityHeader(community: community)),
          SliverPersistentHeader(pinned: true, delegate: _TabBarHeader(_tabBar(context))),
        ],
        body: TweetContextScope(
          child: TabBarView(
            children: [
              PaginatedTweetList(
                feed: _top.feed,
                loadPage: _top.loadPage,
                username: null,
                firstPageErrorPrefix: (l10n) => l10n.unable_to_load_the_tweets,
                newPageErrorPrefix: (l10n) => l10n.unable_to_load_the_next_page_of_tweets,
                emptyMessage: L10n.of(context).no_results,
                onRefresh: () async {},
              ),
              CommunityAbout(community: community),
            ],
          ),
        ),
      ),
    );
  }

  TabBar _tabBar(BuildContext context) => TabBar(
    tabs: [
      Tab(text: L10n.of(context).search_tab_top),
      Tab(text: L10n.of(context).community_about),
    ],
  );
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarHeader(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Material(color: Theme.of(context).colorScheme.surface, child: tabBar);

  @override
  bool shouldRebuild(_TabBarHeader oldDelegate) => tabBar != oldDelegate.tabBar;
}
