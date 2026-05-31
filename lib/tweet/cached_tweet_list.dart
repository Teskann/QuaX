import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/conversation.dart';

/// A plain (non-paginated) list of tweet chains, used to show cached tweets
/// while a feed's first page loads. Expects the tweet context providers to be
/// supplied by an ancestor (e.g. TweetContextScope or the feed body).
class CachedTweetList extends StatelessWidget {
  final List<TweetChain> chains;
  final String? username;

  const CachedTweetList(this.chains, {super.key, this.username});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: chains.length,
      itemBuilder: (context, index) {
        var chain = chains[index];
        return TweetConversation(id: chain.id, tweets: chain.tweets, username: username, isPinned: chain.isPinned);
      },
    );
  }
}
