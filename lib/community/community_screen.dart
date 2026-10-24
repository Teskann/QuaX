import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/community/_about.dart';
import 'package:quax/community/_header.dart';
import 'package:quax/community/community.dart';
import 'package:quax/community/community_model.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/ui/errors.dart';

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

    return Provider(
      create: (_) => CommunityModel(args.id)..load(),
      dispose: (_, CommunityModel model) => model.destroy(),
      child: Builder(
        builder: (context) {
          final model = context.read<CommunityModel>();
          return Scaffold(
            body: ScopedBuilder<CommunityModel, Community>.transition(
              store: model,
              onLoading: (_) => const Center(child: CircularProgressIndicator()),
              onError: (_, error) => FullPageErrorWidget(
                error: error,
                stackTrace: null,
                prefix: (l10n) => l10n.unable_to_load_the_community,
                onRetry: model.load,
              ),
              onState: (_, community) => _CommunityBody(community: community, showAbout: args.showAbout),
            ),
          );
        },
      ),
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
  static const _bannerHeight = 160.0;

  late final _top = CommunityTweetsPagination(widget.community.id);

  @override
  void dispose() {
    _top.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final community = widget.community;
    final prefs = PrefService.of(context);

    return DefaultTabController(
      length: 2,
      initialIndex: widget.showAbout ? 1 : 0,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverAppBar(
              pinned: true,
              expandedHeight: _bannerHeight,
              forceElevated: innerBoxIsScrolled,
              // The banner shows the name until it is scrolled under the app bar
              title: constraints.scrollOffset > _bannerHeight - kToolbarHeight ? Text(community.name) : null,
              flexibleSpace: community.bannerUrl == null
                  ? null
                  : FlexibleSpaceBar(
                      background: CommunityBanner(url: community.bannerUrl!, name: community.name),
                    ),
            ),
          ),
          SliverToBoxAdapter(child: CommunityHeader(community: community)),
          SliverPersistentHeader(pinned: true, delegate: _TabBarHeader(_tabBar(context))),
        ],
        body: MultiProvider(
          providers: [
            ChangeNotifierProvider<TweetContextState>(
              create: (_) => TweetContextState(prefs.get(optionTweetsHideSensitive)),
            ),
            ChangeNotifierProvider<VideoContextState>(
              create: (_) => VideoContextState(prefs.get(optionMediaDefaultMute)),
            ),
          ],
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
