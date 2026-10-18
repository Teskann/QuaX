import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/search/search_query.dart';

import '../fixtures.dart';
import '../tweet/pump_tweets.dart';

String? _rawQuery(Fixture fixture) => Uri.parse(fixture.sourceUrl).queryParameters['q'];

/// The posts X found for [rawQuery], every recorded page included.
List<TweetWithCard> _found(String rawQuery) =>
    fixturesOf('SearchTimeline')
        .where((fixture) => _rawQuery(fixture) == rawQuery)
        .expand((page) => tweetsOf(Twitter.parseSearchTimeline(page.body).chains))
        .where((tweet) => tweet.isTombstone != true)
        .toList();

/// The words of a post as X matches them: Hot-reload is the phrase hot reload.
String _text(TweetWithCard tweet) => (tweet.noteText ?? tweet.fullText ?? tweet.text ?? '').toLowerCase().replaceAll(
  RegExp(r'[^\p{L}\p{N}]+', unicode: true),
  ' ',
);

/// X also searches the body of a linked article, which the timeline leaves out.
bool _linksArticle(TweetWithCard tweet) => ((tweet.noteEntities ?? tweet.entities)?.urls ?? const []).any(
  (url) => '${url.expandedUrl}'.contains('/i/article/'),
);

bool _isFrom(TweetWithCard tweet, List<String> accounts) =>
    accounts.any((account) => tweet.user?.screenName?.toLowerCase() == account.toLowerCase());

bool _hasMedia(TweetWithCard tweet, List<String> types) =>
    tweet.extendedEntities?.media?.any((media) => types.contains(media.type)) ?? false;

bool _hasLink(TweetWithCard tweet) => ((tweet.noteEntities ?? tweet.entities)?.urls ?? const []).isNotEmpty;

/// A count can drop once X indexed the post, when a reply is deleted or a like taken back.
bool _nearlyAtLeast(int? count, int minimum) => (count ?? 0) >= minimum * 0.8;

void _expectEvery(String rawQuery, String filter, bool Function(TweetWithCard tweet) matches) {
  final tweets = _found(rawQuery);
  expect(tweets, isNotEmpty, reason: 'X should find posts for $rawQuery');
  for (final tweet in tweets) {
    expect(matches(tweet), isTrue, reason: 'Post ${tweet.idStr} should be $filter, as $rawQuery asks');
  }
}

void main() {
  test('Should read every recorded filtered search back into the same query', () {
    final queries = fixturesOf('SearchTimeline')
        .where((fixture) => fixture.scenario.startsWith('Search filter'))
        .map(_rawQuery)
        .nonNulls
        .toSet();

    expect(queries, isNotEmpty, reason: 'The filtered searches should be recorded');
    for (final raw in queries) {
      expect(
        SearchQuery.parse(raw, 'fr').compose('fr'),
        raw,
        reason: 'The app should send X the very query the website sent for $raw',
      );
    }
  });

  test('Should only find posts with images for filter:images', () {
    _expectEvery('from:FlutterDev filter:images', 'a post with an image', (tweet) => _hasMedia(tweet, ['photo']));
  });

  test('Should only find posts with a video for filter:videos', () {
    _expectEvery(
      'from:FlutterDev filter:videos',
      'a post with a video',
      (tweet) => _hasMedia(tweet, ['video', 'animated_gif']),
    );
  });

  test('Should only find replies for filter:replies', () {
    _expectEvery('from:FlutterDev filter:replies', 'a reply', (tweet) => tweet.inReplyToStatusIdStr != null);
  });

  test('Should only find posts with a link for filter:links', () {
    _expectEvery('from:FlutterDev filter:links', 'a post with a link', _hasLink);
  });

  test('Should only find posts without a link for -filter:links', () {
    _expectEvery('from:FlutterDev -filter:links', 'a post without a link', (tweet) => !_hasLink(tweet));
  });

  test('Should only find posts in French for lang:fr', () {
    _expectEvery('flutter lang:fr', 'in French', (tweet) => tweet.lang == 'fr');
  });

  test('Should only find posts between the two dates for since: and until:', () {
    _expectEvery('from:FlutterDev since:2025-01-01 until:2025-07-01', 'from the first half of 2025', (tweet) {
      final date = tweet.createdAt!.toUtc();
      return !date.isBefore(DateTime.utc(2025, 1, 1)) && date.isBefore(DateTime.utc(2025, 7, 2));
    });
  });

  test('Should only find posts with enough engagement for min_replies:, min_faves: and min_retweets:', () {
    _expectEvery('from:FlutterDev min_replies:5 min_faves:50 min_retweets:10', 'popular enough', (tweet) {
      return _nearlyAtLeast(tweet.replyCount, 5) &&
          _nearlyAtLeast(tweet.favoriteCount, 50) &&
          _nearlyAtLeast(tweet.retweetCount, 10);
    });
  });

  test('Should only find replies to the account for to:', () {
    _expectEvery(
      'to:FlutterDev',
      'a reply to @FlutterDev',
      (tweet) => tweet.inReplyToScreenName?.toLowerCase() == 'flutterdev',
    );
  });

  test('Should only find posts that mention the account for @', () {
    _expectEvery('@FlutterDev', 'a post mentioning @FlutterDev', (tweet) {
      final mentions = (tweet.noteEntities ?? tweet.entities)?.userMentions ?? const [];
      return mentions.any((mention) => mention.screenName?.toLowerCase() == 'flutterdev') ||
          tweet.inReplyToScreenName?.toLowerCase() == 'flutterdev';
    });
  });

  test('Should only find posts with the exact phrase, one of the words and none of the excluded ones', () {
    _expectEvery('"hot reload" (flutter OR dart) -kotlin', 'about hot reload without Kotlin', (tweet) {
      final text = _text(tweet);
      return (text.contains('hot reload') || _linksArticle(tweet)) && !text.contains('kotlin');
    });
  });

  test('Should only find posts with one of the hashtags', () {
    _expectEvery('(#Flutter OR #Dart) from:FlutterDev', 'tagged #Flutter or #Dart', (tweet) {
      final tags = ((tweet.noteEntities ?? tweet.entities)?.hashtags ?? const []).map((tag) => tag.text?.toLowerCase());
      return tags.contains('flutter') || tags.contains('dart');
    });
  });

  test('Should apply every filter of a combined search', () {
    const raw = 'dart (from:FlutterDev OR from:dart_lang) lang:en -filter:replies filter:links since:2025-01-01';
    _expectEvery(raw, 'an English post with a link, not a reply, by one of the accounts, since 2025', (tweet) {
      return _isFrom(tweet, ['FlutterDev', 'dart_lang']) &&
          tweet.lang == 'en' &&
          tweet.inReplyToStatusIdStr == null &&
          _hasLink(tweet) &&
          !tweet.createdAt!.toUtc().isBefore(DateTime.utc(2025, 1, 1));
    });
  });
}
