import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/refreshed_profiles.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';

/// A page of the subscriptions feed of @FlutterDev and @dart_lang
TweetStatus _feedPage() {
  final feed =
      fixture('SearchTimeline', 'from-flutterdev-or-from-dart-lang-filter-replies-filter-retweets', unstable: true);
  return Twitter.parseSearchTimeline(feed.body);
}

UserSubscription _subscriptionTo(UserWithExtra user, {String? name, String? picture}) => UserSubscription(
    id: user.idStr!,
    screenName: user.screenName!,
    name: name ?? user.name!,
    profileImageUrlHttps: picture ?? user.profileImageUrlHttps,
    verified: false,
    createdAt: DateTime(2026),
    inFeed: true);

UserWithExtra _firstAuthorOf(TweetStatus page) => authorsOf(page.chains).first;

void main() {
  test('Should replace the picture an account changed since it was subscribed to', () {
    final author = _firstAuthorOf(_feedPage());
    final stale = _subscriptionTo(author, picture: 'https://pbs.twimg.com/profile_images/1/deleted_normal.jpg');

    final refreshed = refreshedSubscriptions([stale], [author]);

    expect(author.profileImageUrlHttps, isNotNull, reason: 'The recorded feed should send the picture of its authors');
    expect(refreshed[author.idStr]?.profileImageUrlHttps, author.profileImageUrlHttps,
        reason: 'The old link stops working once the account changes its picture, see #283');
  });

  test('Should replace the name an account changed since it was subscribed to', () {
    final author = _firstAuthorOf(_feedPage());

    final refreshed = refreshedSubscriptions([_subscriptionTo(author, name: 'Old name')], [author]);

    expect(refreshed[author.idStr]?.name, author.name, reason: 'The list should show the name the account uses now');
  });

  test('Should not save anything when the profile did not change', () {
    final page = _feedPage();
    final subscriptions = authorsOf(page.chains).map(_subscriptionTo).toList();

    expect(refreshedSubscriptions(subscriptions, authorsOf(page.chains)), isEmpty,
        reason: 'Every feed load goes through here, so an unchanged profile must not write to the database');
  });

  test('Should ignore the authors the user is not subscribed to', () {
    final page = _feedPage();
    final stranger = UserSubscription(
        id: '1',
        screenName: 'stranger',
        name: 'Stranger',
        profileImageUrlHttps: null,
        verified: false,
        createdAt: DateTime(2026),
        inFeed: true);

    expect(refreshedSubscriptions([stranger], authorsOf(page.chains)), isEmpty,
        reason: 'Only the accounts in the subscriptions have a stored profile to refresh');
  });

  test('Should keep the stored picture when X sent none', () {
    final author = _firstAuthorOf(_feedPage());
    final stored = _subscriptionTo(author);
    author.profileImageUrlHttps = null;

    expect(refreshedSubscriptions([stored], [author]), isEmpty,
        reason: 'A missing field in the answer of X says nothing about the picture of the account');
  });

  test('Should refresh the author of a reposted or quoted post as well', () {
    final page = _feedPage();
    final reposted = UserWithExtra()
      ..idStr = '42'
      ..screenName = 'reposted'
      ..name = 'Reposted'
      ..profileImageUrlHttps = 'https://pbs.twimg.com/profile_images/42/new_normal.jpg';
    page.chains.first.tweets.first.retweetedStatusWithCard = TweetWithCard()..user = reposted;

    final refreshed = refreshedSubscriptions([_subscriptionTo(reposted, picture: 'old')], authorsOf(page.chains));

    expect(refreshed['42']?.profileImageUrlHttps, reposted.profileImageUrlHttps,
        reason: 'The author of a repost is sent whole by X, so it is as fresh as the one who reposted');
  });
}
