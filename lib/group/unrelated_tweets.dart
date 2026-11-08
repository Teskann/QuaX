import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';

bool feedContainsUnrelatedTweets(TweetStatus tweets, List<SearchableSubscription> subscriptions) {
  // A saved search brings tweets of any author
  final followsOnlyAuthors = subscriptions.every((subscription) => switch (subscription) {
        UserSubscription() => true,
        SearchSubscription() => false,
      });
  if (!followsOnlyAuthors) {
    return false;
  }
  final ids = subscriptions.map((subscription) => subscription.id).toSet();
  return tweets.chains
      .expand((chain) => chain.tweets)
      .map((tweet) => tweet.user?.idStr)
      .any((id) => id != null && !ids.contains(id));
}
