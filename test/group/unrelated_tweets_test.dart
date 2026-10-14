import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/unrelated_tweets.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';

/// A page of the subscriptions feed of @FlutterDev and @dart_lang, where every post comes from one of them
TweetStatus _feedPage() => Twitter.parseSearchTimeline(
    fixture('SearchTimeline', 'from-flutterdev-or-from-dart-lang-filter-replies-filter-retweets', unstable: true).body);

Iterable<TweetWithCard> _tweetsOf(TweetStatus page) => page.chains.expand((chain) => chain.tweets);

UserSubscription _subscription(String id, String screenName) => UserSubscription(
    id: id,
    screenName: screenName,
    name: screenName,
    profileImageUrlHttps: null,
    verified: false,
    createdAt: DateTime(2026),
    inFeed: true);

/// The subscriptions of the authors of [page], with their handles changed by [handle]
List<Subscription> _authorsOf(TweetStatus page, {String Function(String screenName)? handle}) {
  final authors = {for (final tweet in _tweetsOf(page)) tweet.user!.idStr!: tweet.user!.screenName!};
  return authors.entries.map((author) => _subscription(author.key, (handle ?? (name) => name)(author.value))).toList();
}

void main() {
  test('Should not flag a feed where every post comes from a subscription', () {
    final page = _feedPage();

    expect(_tweetsOf(page), isNotEmpty, reason: 'The recorded feed should hold posts to check');
    expect(feedContainsUnrelatedTweets(page, _authorsOf(page)), isFalse,
        reason: 'Posts of the subscriptions are what the feed is made of');
  });

  test('Should not flag a subscription whose handle was stored with another casing', () {
    final page = _feedPage();

    expect(feedContainsUnrelatedTweets(page, _authorsOf(page, handle: (name) => name.toLowerCase())), isFalse,
        reason: 'X handles are case-insensitive, so the casing stored at subscription time does not matter');
  });

  test('Should not flag an account that renamed itself since it was subscribed to', () {
    final page = _feedPage();

    expect(feedContainsUnrelatedTweets(page, _authorsOf(page, handle: (name) => 'old_$name')), isFalse,
        reason: 'The account is the same, only its stored handle is stale');
  });

  test('Should not check a chunk holding a keyword subscription', () {
    final page = _feedPage();
    final oneAuthor = _authorsOf(page).take(1).toList();
    final keyword = SearchSubscription(id: 'flutter', createdAt: DateTime(2026));

    expect(feedContainsUnrelatedTweets(page, oneAuthor), isTrue,
        reason: 'Without the keyword, the posts of the other author do not belong to the chunk');
    expect(feedContainsUnrelatedTweets(page, [...oneAuthor, keyword]), isFalse,
        reason: 'A keyword matches posts from anyone, so any author can legitimately show up');
  });

  test('Should flag a post from someone the user is not subscribed to', () {
    final page = _feedPage();
    final subscriptions = _authorsOf(page);
    _tweetsOf(page).last.user = (UserWithExtra()
      ..idStr = '1'
      ..screenName = 'stranger');

    expect(feedContainsUnrelatedTweets(page, subscriptions), isTrue,
        reason: 'A post from an account outside the subscriptions is the bug of X the warning is about');
  });
}
