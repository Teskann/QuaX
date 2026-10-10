import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/feed_session_cache.dart';
import 'package:quax/home/_x_feed_header.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';

import '../ui/pump_app.dart';
import 'x_pump.dart';

void main() {
  group('XFeedTab cache key', () {
    test('Should give each tab its own stable key', () {
      final tabs = xFeedTabs([fakeGroup('g1', 'Friends'), fakeGroup('g2', 'News')]);
      final keys = tabs.map((e) => e.cacheKey).toList();

      expect(keys.toSet().length, tabs.length, reason: 'Tabs must not share the state of their feed');
      expect(xFeedTabs([fakeGroup('g1', 'Friends')])[2].cacheKey, keys[2],
          reason: 'The key must survive a reload of the groups');
    });

    test('Should not collide with the key of a group opened on its own', () {
      expect(xFeedTabs([fakeGroup('g1', 'Friends')]).map((e) => e.cacheKey), isNot(contains('g1')),
          reason: 'A pushed group screen uses the group id as key');
    });
  });

  group('Switching tabs', () {
    testWidgets('Should not load a feed again when coming back to its tab', (tester) async {
      final cache = FeedSessionCache();
      final loads = <String, int>{};
      final tab = ValueNotifier('x-home:following');

      Widget feedOf(String key) => PaginatedTweetList(
            key: ValueKey(key),
            feed: cache.getOrCreateController(key),
            loadPage: (cursor) async {
              loads.update(key, (n) => n + 1, ifAbsent: () => 1);
              return (chains: <TweetChain>[], nextCursor: null);
            },
            username: null,
            firstPageErrorPrefix: (l10n) => 'Unable to load',
            newPageErrorPrefix: (l10n) => 'Unable to load more',
            emptyMessage: 'Nothing here',
          );

      await pumpInApp(
          tester,
          Provider<FeedSessionCache>.value(
              value: cache,
              child: ValueListenableBuilder(valueListenable: tab, builder: (_, key, _) => feedOf(key))));
      expect(loads, {'x-home:following': 1}, reason: 'The first visit loads the feed');

      tab.value = 'x-home:g1';
      await tester.pumpAndSettle();
      tab.value = 'x-home:following';
      await tester.pumpAndSettle();

      expect(loads, {'x-home:following': 1, 'x-home:g1': 1}, reason: 'Coming back to a tab should restore its feed');

      cache.invalidateAll();
      tab.value = 'x-home:g1';
      await tester.pumpAndSettle();
      expect(loads['x-home:g1'], 2, reason: 'After a reload of the subscriptions the feed loads again');
    });
  });
}
