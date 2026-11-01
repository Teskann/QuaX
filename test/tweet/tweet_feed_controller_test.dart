import 'dart:async';

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

  test('Should not load a next page during a refresh, and follow the refreshed page afterwards', () async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    final refreshed = Completer<TweetPageResult>();
    final cursors = <String?>[];
    feed.loader = (cursor) {
      cursors.add(cursor);
      return cursor == null ? refreshed.future : Future.value((chains: [chain('next')], nextCursor: 'after'));
    };
    feed.seed([chain('cached')], 'cached');

    final refresh = feed.softRefresh();
    feed.controller.fetchNextPage();
    await pumpEventQueue();
    refreshed.complete((chains: [chain('fresh')], nextCursor: 'fresh'));
    await refresh;
    feed.controller.fetchNextPage();
    await pumpEventQueue();

    expect(cursors, [null, 'fresh'],
        reason: 'A next page loaded during the refresh would follow the cached tweets and mix with the fresh ones');
    expect(feed.items.map((e) => e.id), ['fresh', 'next'], reason: 'The cached tweets should be replaced, not mixed in');
  });
}
