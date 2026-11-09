import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/lists/_header.dart';
import 'package:quax/lists/x_list_model.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/timeline_pagination.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
import 'package:quax/ui/header_banner.dart';
import 'package:quax/ui/loaded_page.dart';

class XListScreenArguments {
  final String id;

  /// Opens the members page on top of the list. A link to the members does the same.
  final bool showMembers;

  XListScreenArguments(this.id, {this.showMembers = false});
}

class XListScreen extends StatelessWidget {
  const XListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as XListScreenArguments;

    return LoadedPage<LoadedXList>(
      create: () => XListModel(args.id),
      errorPrefix: (l10n) => l10n.unable_to_load_the_list,
      builder: (_, loaded) => _XListBody(loaded: loaded, showMembers: args.showMembers),
    );
  }
}

class _XListBody extends StatefulWidget {
  final LoadedXList loaded;
  final bool showMembers;

  const _XListBody({required this.loaded, required this.showMembers});

  @override
  State<_XListBody> createState() => _XListBodyState();
}

class _XListBodyState extends State<_XListBody> {
  late final _tweets = TimelinePagination((cursor) => Twitter.getListTweets(widget.loaded.list.id, cursor: cursor));

  @override
  void initState() {
    super.initState();
    if (widget.showMembers) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) openListMembers(context, widget.loaded);
      });
    }
  }

  @override
  void dispose() {
    _tweets.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.loaded.list;
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        BannerAppBar(name: list.name, bannerUrl: list.bannerUrl, innerBoxIsScrolled: innerBoxIsScrolled),
        SliverToBoxAdapter(child: XListHeader(loaded: widget.loaded)),
      ],
      body: TweetContextScope(
        child: PaginatedTweetList(
          feed: _tweets.feed,
          loadPage: _tweets.loadPage,
          username: null,
          firstPageErrorPrefix: (l10n) => l10n.unable_to_load_the_tweets,
          newPageErrorPrefix: (l10n) => l10n.unable_to_load_the_next_page_of_tweets,
          emptyMessage: L10n.of(context).no_results,
          onRefresh: () async {},
        ),
      ),
    );
  }
}
