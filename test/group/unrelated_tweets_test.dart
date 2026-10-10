import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/_feed.dart';

UserSubscription subscription(String id, String screenName) => UserSubscription(
    id: id,
    screenName: screenName,
    name: screenName,
    profileImageUrlHttps: null,
    verified: false,
    createdAt: DateTime(2026),
    inFeed: true);

TweetWithCard tweetBy(String? idStr, {String screenName = 'someone'}) => TweetWithCard()
  ..user = (User()
    ..idStr = idStr
    ..screenName = screenName);

TweetStatus status(List<TweetWithCard> tweets) =>
    TweetStatus(chains: [TweetChain(id: 'chain', tweets: tweets, isPinned: false)], cursorBottom: null, cursorTop: null);

void main() {
  group('feedContainsUnrelatedTweets', () {
    test('Should accept posts written by a subscription of the chunk', () {
      final result = feedContainsUnrelatedTweets(status([tweetBy('1')]), [subscription('1', 'alice')]);

      expect(result, isFalse, reason: 'The author is one of the subscriptions, whatever the handle says');
    });

    test('Should flag a post written by someone outside the chunk', () {
      final result = feedContainsUnrelatedTweets(status([tweetBy('1'), tweetBy('2')]), [subscription('1', 'alice')]);

      expect(result, isTrue, reason: 'An author with an id the chunk does not hold is a real unrelated post');
    });

    test('Should ignore a post without author', () {
      final result = feedContainsUnrelatedTweets(status([TweetWithCard()]), [subscription('1', 'alice')]);

      expect(result, isFalse, reason: 'A post with no author cannot be told apart from the subscriptions');
    });

    test('Should ignore an author without id', () {
      final result = feedContainsUnrelatedTweets(status([tweetBy(null)]), [subscription('1', 'alice')]);

      expect(result, isFalse, reason: 'Without an id there is nothing reliable to compare, so no false alarm');
    });

    test('Should skip the check for a chunk holding a keyword subscription', () {
      final users = [subscription('1', 'alice'), SearchSubscription(id: 'flutter', createdAt: DateTime(2026))];

      expect(feedContainsUnrelatedTweets(status([tweetBy('2')]), users), isFalse,
          reason: 'A keyword matches posts from any author, so an outside author is legitimate');
    });

    test('Should not flag a renamed account or a handle with another casing', () {
      final result = feedContainsUnrelatedTweets(
          status([tweetBy('1', screenName: 'ALICE_NEW'), tweetBy('1', screenName: 'Alice')]),
          [subscription('1', 'alice')]);

      expect(result, isFalse, reason: 'The id is the same, only the handle differs');
    });

    test('Should flag an unrelated post in any chain', () {
      final tweets = TweetStatus(chains: [
        TweetChain(id: 'a', tweets: [tweetBy('1')], isPinned: false),
        TweetChain(id: 'b', tweets: [tweetBy('1'), tweetBy('3')], isPinned: false),
      ], cursorBottom: null, cursorTop: null);

      expect(feedContainsUnrelatedTweets(tweets, [subscription('1', 'alice')]), isTrue,
          reason: 'Every post of every chain should be checked');
    });

    test('Should accept an empty page', () {
      final empty = TweetStatus(chains: [], cursorBottom: null, cursorTop: null);

      expect(feedContainsUnrelatedTweets(empty, [subscription('1', 'alice')]), isFalse,
          reason: 'A page with no post has nothing unrelated');
    });
  });

  group('unrelatedPostsWarningAfterPage', () {
    bool after({bool found = false, bool disabled = false, bool isFirstPage = true, bool shown = false}) =>
        unrelatedPostsWarningAfterPage(found: found, disabled: disabled, isFirstPage: isFirstPage, shown: shown);

    test('Should show the warning when a page has unrelated posts', () {
      expect(after(found: true), isTrue, reason: 'Unrelated posts are what the warning is about');
    });

    test('Should never show the warning once the user disabled it', () {
      expect(after(found: true, disabled: true, shown: true, isFirstPage: false), isFalse,
          reason: 'The user asked not to be warned');
    });

    test('Should take the warning down when a refresh finds nothing unrelated', () {
      expect(after(shown: true), isFalse, reason: 'The first page starts over, so the old warning no longer applies');
    });

    test('Should keep the warning while the next pages are clean', () {
      expect(after(shown: true, isFirstPage: false), isTrue, reason: 'The warning stays until the next refresh');
    });

    test('Should stay hidden when nothing is unrelated', () {
      expect(after(isFirstPage: false), isFalse, reason: 'There is nothing to warn about');
    });
  });
}
