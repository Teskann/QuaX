import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_scroll_controller.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/home/_feed.dart';
import 'package:quax/tweet/conversation.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'open_feed.dart';

final _stored = Twitter.parseSearchTimeline(
        fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body)
    .chains;

String _topTweet(WidgetTester tester) => tester
    .widgetList<TweetConversation>(find.byType(TweetConversation))
    .where((tweet) => tester.getBottomLeft(find.byWidget(tweet)).dy > 80)
    .reduce((a, b) => tester.getTopLeft(find.byWidget(a)).dy <= tester.getTopLeft(find.byWidget(b)).dy ? a : b)
    .id;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());
  useFreshDatabase();

  testWidgets('Should reopen the main feed on the tweet left at its top', (tester) async {
    await tester.runAsync(() async {
      final repository = await Repository.writable();
      await repository.insert(tableSubscription, flutterDev.toMap());
      final hash = feedChunksOf(await readSubscriptionGroup(repository, '-1')).single.hash;
      await storeChunkPage(repository, hash, TweetStatus(chains: _stored, cursorBottom: 'stored', cursorTop: null),
          firstPage: true);
      await storeFeedPosition(repository, '-1', _stored[5].id);
    });
    final sent = <Uri>[];
    Twitter.client = FixtureTwitterClient({}, requestedUris: sent);

    await pumpInApp(tester, withAppModels(FeedScreen(scrollController: FeedScrollController(), id: '-1', name: 'Feed')),
        settle: false, prefs: {optionMediaDisableAutoload: true, optionKeepFeedOffset: true});
    await settleFeed(tester);

    expect(sent, isEmpty, reason: 'New tweets should only load when the user pulls down');
    expect(_topTweet(tester), _stored[5].id, reason: 'The feed should reopen where it was left');
  });
}
