import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/utils/paging.dart';

TweetChain chain(String id) => TweetChain(id: id, tweets: const [], isPinned: false);

void main() {
  group('TweetFeedController.softRefresh()', () {
    test('Should keep a failed refresh apart from the paging error when tweets are shown', () async {
      final feed = TweetFeedController();
      addTearDown(feed.dispose);
      feed.loader = (cursor) async => (chains: [chain('1')], nextCursor: 'next');
      await feed.softRefresh();

      feed.loader = (cursor) async => throw StateError('refresh failed');
      await feed.softRefresh();

      expect(feed.refreshError.value, isNotNull, reason: 'The error should be shown above the tweets');
      expect(pagingErrorOf(feed.controller.value), isNull,
          reason: 'A paging error would show at the bottom and block loading the next pages');
      expect(feed.controller.value.items?.map((e) => e.id), ['1'],
          reason: 'A failed refresh should leave the tweets the user is reading in place');
    });

    test('Should report a failed first load as a paging error when no tweet is shown', () async {
      final feed = TweetFeedController();
      addTearDown(feed.dispose);
      feed.loader = (cursor) async => throw StateError('first load failed');

      await feed.softRefresh();

      expect(pagingErrorOf(feed.controller.value), isNotNull,
          reason: 'With nothing loaded, the list shows the error in place of the first page');
      expect(feed.refreshError.value, isNull, reason: 'There are no tweets to show the error above');
    });

    test('Should clear the refresh error once a refresh succeeds', () async {
      final feed = TweetFeedController();
      addTearDown(feed.dispose);
      feed.loader = (cursor) async => (chains: [chain('1')], nextCursor: 'next');
      await feed.softRefresh();
      feed.loader = (cursor) async => throw StateError('refresh failed');
      await feed.softRefresh();

      feed.loader = (cursor) async => (chains: [chain('2')], nextCursor: 'next');
      await feed.softRefresh();

      expect(feed.refreshError.value, isNull, reason: 'The error card should go away once the tweets are fresh');
    });
  });
}
