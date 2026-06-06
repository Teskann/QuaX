import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import '../constants.dart';

final UserWithExtra user = UserWithExtra.fromArguments(idStr: "1", possiblySensitive: false, screenName: "ForYou");

class ForYouTweets extends StatefulWidget {
  final TweetFeedController feed;
  final String type;
  final bool includeReplies;
  final BasePrefService pref;

  const ForYouTweets(this.feed,
      {super.key, required this.type, required this.includeReplies, required this.pref});

  @override
  State<ForYouTweets> createState() => _ForYouTweetsState();
}

class _ForYouTweetsState extends State<ForYouTweets> with AutomaticKeepAliveClientMixin<ForYouTweets> {
  static const int pageSize = 20;
  int loadTweetsCounter = 0;
  @override
  bool get wantKeepAlive => true;

  void incrementLoadTweetsCounter() {
    ++loadTweetsCounter;
  }

  int getLoadTweetsCounter() {
    return loadTweetsCounter;
  }

  Future<TweetPageResult> _loadTweets(String? cursor) async {
    final result = await Twitter.getTimelineTweets(
      user.idStr!,
      widget.type,
      cursor: cursor,
      count: pageSize,
      includeReplies: widget.includeReplies,
      getTweetsCounter: getLoadTweetsCounter,
      incrementTweetsCounter: incrementLoadTweetsCounter,
    );
    return (chains: result.chains, nextCursor: result.cursorBottom);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return MultiProvider(
        providers: [
          ChangeNotifierProvider<TweetContextState>(
              create: (_) => TweetContextState(PrefService.of(context).get(optionTweetsHideSensitive)))
        ],
        builder: (context, child) {
          return Consumer<TweetContextState>(builder: (context, model, child) {
            if (model.hideSensitive && (user.possiblySensitive ?? false)) {
              return EmojiErrorWidget(
                emoji: '🍆🙈🍆',
                message: L10n.current.possibly_sensitive,
                errorMessage: L10n.current.possibly_sensitive_profile,
                onRetry: () async => model.setHideSensitive(false),
                retryText: L10n.current.yes_please,
              );
            }

            return PaginatedTweetList(
              feed: widget.feed,
              loadPage: _loadTweets,
              username: user.screenName,
              onRefresh: () async {},
              firstPageErrorPrefix: L10n.of(context).unable_to_load_the_tweets,
              newPageErrorPrefix: L10n.of(context).unable_to_load_the_next_page_of_tweets,
              emptyMessage: L10n.of(context).unable_to_load_the_tweets_for_the_feed,
            );
          });
        });
  }
}
