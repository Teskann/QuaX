import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/user.dart';

Iterable<UserWithExtra> authorsOf(Iterable<TweetChain> chains) => chains
    .expand((chain) => chain.tweets)
    .expand((tweet) => [tweet, tweet.retweetedStatusWithCard, tweet.quotedStatusWithCard])
    .map((tweet) => tweet?.user)
    .whereType<UserWithExtra>();

/// The user subscriptions whose name or picture differ from what X just sent, by id
Map<String, UserSubscription> refreshedSubscriptions(List<Subscription> subscriptions, Iterable<UserWithExtra> users) {
  final usersById = {for (final user in users.where((user) => user.idStr != null)) user.idStr!: user};
  return {
    for (final subscription in subscriptions.whereType<UserSubscription>())
      if (usersById[subscription.id] case final user?)
        if (subscription.copyWith(name: user.name, profileImageUrlHttps: user.profileImageUrlHttps)
            case final refreshed when _profileChanged(subscription, refreshed))
          subscription.id: refreshed
  };
}

bool _profileChanged(UserSubscription stored, UserSubscription refreshed) =>
    stored.name != refreshed.name || stored.profileImageUrlHttps != refreshed.profileImageUrlHttps;
