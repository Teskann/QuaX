import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/client/client.dart';
import 'package:quax/profile/profile_model.dart';

import '../fixtures.dart';

int _counter = 0;

TweetStatus profileTimeline(Fixture fixture) => Twitter.createUnconversationedChains(
      fixture.body,
      'tweet',
      const [],
      false,
      true,
      true,
      () => _counter,
      () => _counter++,
    );

/// Every tweet in a timeline, threads flattened.
List<TweetWithCard> allTweets(TweetStatus status) =>
    status.chains.expand((chain) => chain.tweets).toList();

/// The check that matters most across every fixture: X stopped sending a
/// `legacy` block on users, and the code used to skip the author silently when
/// it was missing. A tweet without an author renders blank, without an error.
void expectEveryTweetHasAnAuthor(List<TweetWithCard> tweets, Fixture fixture) {
  final orphans = tweets
      .where((tweet) => tweet.isTombstone != true)
      .where((tweet) => tweet.user?.screenName == null)
      .map((tweet) => tweet.idStr ?? '?')
      .toList();
  expect(orphans, isEmpty,
      reason: 'Every tweet should carry its author. ${orphans.length} of ${tweets.length} '
          'have none, so they would render with no name and no avatar. '
          'Fixture: ${fixture.path}');
}

void main() {
  // parseProfile words its errors through L10n, so the delegate has to be
  // loaded before any of them can be raised.
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await L10n.load(const Locale('en'));
  });

  group('UserByScreenName', () {
    for (final fixture in fixturesOf('UserByScreenName')) {
      test(fixture.scenario, () {
        Profile? profile;
        TwitterError? error;
        try {
          profile = Twitter.parseProfile(fixture.body, fixture.sourceUrl);
        } on TwitterError catch (thrown) {
          error = thrown;
        }

        if (profile == null) {
          // A profile that cannot be read must say why. Silence here shows as a
          // blank screen with no explanation.
          expect(error?.code, anyOf(50, 63, -1),
              reason: 'An unreadable profile should raise a known error: 50 not found, '
                  '63 suspended, -1 otherwise unavailable');
          return;
        }

        final user = profile.user;
        expect(user.idStr, isNotEmpty,
            reason: 'The profile should keep its numeric id, which every later request needs');
        expect(user.screenName, isNotEmpty,
            reason: 'The profile should keep its handle, which titles the screen');
        expect(user.name, isNotNull,
            reason: 'The profile should keep its display name');
        expect(user.createdAt, isNotNull,
            reason: 'The join date should parse from the X date format');
        expect(user.profileImageUrlHttps, isNotNull,
            reason: 'The avatar URL should be read, now that it moved out of the legacy block');
        expect(user.followersCount, isNotNull,
            reason: 'The follower count should be read from relationship_counts');
        expect(user.statusesCount, isNotNull,
            reason: 'The tweet count should be read from tweet_counts');
      });
    }
  });

  group('Unavailable posts', () {
    test('Should keep a deleted post opened directly as an unavailable post', () {
      final fixture = fixturesOf('TweetDetail').firstWhere((f) => f.path.endsWith('2095934459606376826.json'));
      final chains = Twitter.parseTweetDetail(fixture.body).chains;

      expect(chains.map((chain) => chain.id), ['2095934459606376826'],
          reason: 'X sends an empty entry for the opened post, which should still be listed, '
              'otherwise the screen says the user has no posts');
      expect(chains.single.tweets.single.isTombstone, isTrue,
          reason: 'The empty entry should show as an unavailable post');
    });
  });

  group('TweetDetail', () {
    for (final fixture in fixturesOf('TweetDetail')) {
      test(fixture.scenario, () {
        final tweets = allTweets(Twitter.parseTweetDetail(fixture.body));
        expect(tweets, isNotEmpty,
            reason: 'Opening a tweet should yield at least the tweet itself');
        expectEveryTweetHasAnAuthor(tweets, fixture);
      });
    }
  });

  group('UserTweets', () {
    for (final fixture in fixturesOf('UserTweets')) {
      test(fixture.scenario, () {
        final status = profileTimeline(fixture);
        final tweets = allTweets(status);
        expect(tweets, isNotEmpty,
            reason: 'A profile timeline with posts should yield tweets');
        expect(status.cursorBottom, isNotNull,
            reason: 'A timeline should expose a bottom cursor, or the next page is unreachable');
        expectEveryTweetHasAnAuthor(tweets, fixture);
      });
    }
  });

  group('SearchTimeline', () {
    for (final fixture in fixturesOf('SearchTimeline')) {
      test(fixture.scenario, () {
        // The People tab answers under another root, and the parser returns an
        // empty status rather than throwing. That is the behaviour under test.
        expectEveryTweetHasAnAuthor(allTweets(Twitter.parseSearchTimeline(fixture.body)), fixture);
      });
    }
  });

  for (final operation in ['Following', 'Followers']) {
    group(operation, () {
      for (final fixture in fixturesOf(operation)) {
        test(fixture.scenario, () {
          final page = Twitter.parseFollows(fixture.body);
          expect(page.users, isNotNull,
              reason: 'A follow list should come back as a list, even an empty one');

          final anonymous = page.users!.where((user) => user.screenName == null).length;
          expect(anonymous, 0,
              reason: 'Each account in the list should keep its handle. '
                  'They used to be dropped whole when the legacy block went missing.');
        });
      }
    });
  }
}
