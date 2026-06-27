import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/utils/iterables.dart';

class TweetConversation extends StatefulWidget {
  final String id;
  final String? username;
  final bool isPinned;
  final List<TweetWithCard> tweets;
  final bool tweetOpened;
  final int initialMediaIndex;

  const TweetConversation(
      {super.key,
      required this.id,
      required this.username,
      required this.isPinned,
      required this.tweets,
      this.tweetOpened = false,
      this.initialMediaIndex = 0});

  @override
  State<TweetConversation> createState() => _TweetConversationState();
}

class _TweetConversationState extends State<TweetConversation> {
  @override
  Widget build(BuildContext context) {
    if (widget.tweets.length == 1) {
      return TweetTile(
          clickable: true,
          tweet: widget.tweets.first,
          currentUsername: widget.username,
          isPinned: widget.isPinned,
          tweetOpened: widget.tweetOpened,
          initialMediaIndex: widget.initialMediaIndex);
    }

    var tiles = <Widget>[];
    var tweets = widget.tweets.sorted((a, b) => a.idStr!.compareTo(b.idStr!)).toList(growable: false);

    for (var i = 0; i < tweets.length; i++) {
      tiles.add(TweetTile(
          clickable: true,
          tweet: tweets[i],
          currentUsername: widget.username,
          isPinned: widget.isPinned,
          isThread: i == 0,
          threadConnectTop: i > 0,
          threadConnectBottom: i < tweets.length - 1,
          initialMediaIndex: tweets[i].idStr == widget.id ? widget.initialMediaIndex : 0));
    }

    // One rounded card for the whole thread, so its tweets read as a single surface. The trailing
    // divider matches the one every standalone tweet draws below itself.
    return Column(
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          color: tweetCardColor(context),
          child: Column(
            children: [
              ...tiles,
            ],
          ),
        ),
        Divider(
          height: 0,
          thickness: 1,
          color: Theme.of(context).colorScheme.surfaceBright.withAlpha(150),
        ),
      ],
    );
  }
}
