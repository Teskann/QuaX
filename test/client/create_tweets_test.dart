import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';

Map<String, dynamic> gridItem(Map<String, dynamic> tweetResults) => {
      'item': {
        'itemContent': {'tweet_results': tweetResults},
      },
    };

void main() {
  group('Twitter.createTweets()', () {
    test('Should skip a photo grid item whose tweet_results is empty', () {
      final entries = [
        {
          'entryId': 'profile-photo-grid-0',
          'content': {
            'items': [gridItem(<String, dynamic>{})],
          },
        },
      ];

      expect(Twitter.createTweets(entries), isEmpty,
          reason: 'X sends an empty tweet_results for a post it cannot show, which must not break the whole page');
    });

    test('Should skip a tweet entry whose tweet_results is empty', () {
      final entries = [
        {
          'entryId': 'tweet-1',
          'content': {
            'itemContent': {'tweet_results': <String, dynamic>{}},
          },
        },
      ];

      expect(Twitter.createTweets(entries), isEmpty,
          reason: 'An unavailable post in the timeline must be skipped rather than throw');
    });
  });
}
