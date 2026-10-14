import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';

bool feedContainsUnrelatedTweets(TweetStatus tweets, List<Subscription> subscriptions) {
  if (subscriptions.any((subscription) => subscription is SearchSubscription)) {
    return false;
  }
  final ids = subscriptions.map((subscription) => subscription.id).toSet();
  return tweets.chains
      .expand((chain) => chain.tweets)
      .map((tweet) => tweet.user?.idStr)
      .any((id) => id != null && !ids.contains(id));
}
