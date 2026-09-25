import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/conversation.dart';

/// A plain (non-paginated) list of tweet chains, used to show cached tweets
/// while a feed's first page loads. Expects the tweet context providers to be
/// supplied by an ancestor (e.g. TweetContextScope or the feed body).
class CachedTweetList extends StatelessWidget {
  final List<TweetChain> chains;
  final String? username;

  /// Shown above the tweets, such as the error of the load meant to replace them
  final Widget? header;

  const CachedTweetList(this.chains, {super.key, this.username, this.header});

  @override
  Widget build(BuildContext context) {
    final header = this.header;
    final offset = header == null ? 0 : 1;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4),
      itemCount: chains.length + offset,
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header;
        var chain = chains[index - offset];
        return TweetConversation(id: chain.id, tweets: chain.tweets, username: username, isPinned: chain.isPinned);
      },
    );
  }
}
