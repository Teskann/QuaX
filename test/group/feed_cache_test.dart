import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/feed_cache.dart';

import '../fixtures.dart';

List<TweetChain> _chains() =>
    Twitter.parseSearchTimeline(fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body).chains;

void main() {
  group('unseenChains()', () {
    test('Should list once a tweet sent by two chunks', () {
      final chains = _chains();

      final unseen = unseenChains([...chains, ...chains]);

      expect(unseen.map((e) => e.id), chains.map((e) => e.id), reason: 'Each tweet should be listed once');
    });

    test('Should leave out the tweets already shown', () {
      final chains = _chains();

      final unseen = unseenChains(chains, chains.take(1));

      expect(unseen.map((e) => e.id), chains.skip(1).map((e) => e.id),
          reason: 'A tweet a previous page already listed should not come again at the bottom of the feed');
    });
  });

  group('feedCursorOf()', () {
    test('Should end the feed when no chunk has a next page', () {
      expect(feedCursorOf([null, null]), isNull, reason: 'There is nothing more to load');
    });

    test('Should go on while one chunk has a next page', () {
      expect(feedCursorOf([null, 'next']), isNotNull, reason: 'The chunk with a cursor still has tweets to load');
    });
  });
}
