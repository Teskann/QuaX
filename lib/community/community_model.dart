import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/community.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';

class CommunityModel extends Store<Community> {
  final String id;

  CommunityModel(this.id) : super(Community(id: id, name: ''));

  Future<void> load() => execute(() => Twitter.getCommunity(id));
}

class CommunityTweetsPagination {
  final TweetFeedController feed = TweetFeedController();
  final String communityId;

  CommunityTweetsPagination(this.communityId);

  Future<TweetPageResult> loadPage(String? cursor) async {
    final result = await Twitter.getCommunityTweets(communityId, cursor: cursor);
    return (chains: result.chains, nextCursor: result.cursorBottom);
  }

  void dispose() => feed.dispose();
}
