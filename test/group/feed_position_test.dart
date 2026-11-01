import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/_feed.dart';
import 'package:quax/group/feed_scroll_controller.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/tweet/tweet.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'open_feed.dart';

final _stored = Twitter.parseSearchTimeline(
        fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body)
    .chains;

Future<void> _storeFeed(WidgetTester tester, {String? position}) => tester.runAsync(() async {
      final repository = await Repository.writable();
      await storeChunkPage(repository, flutterDevChunk.hash,
          TweetStatus(chains: _stored, cursorBottom: 'stored', cursorTop: null),
          firstPage: true);
      if (position != null) {
        await storeFeedPosition(repository, '-1', position);
      }
    });

Future<String?> _position(WidgetTester tester) =>
    tester.runAsync<String?>(() async => readFeedPosition(await Repository.readOnly(), '-1'));

Finder _tweet(TweetChain chain) => find.byWidgetPredicate((w) => w is TweetConversation && w.id == chain.id);

/// Returns the first tweet whose top is visible. If there is none, returns the tweet that covers the top of the screen.
String _topTweet(WidgetTester tester) {
  final shown = tester
      .widgetList<TweetConversation>(find.byType(TweetConversation))
      .map((tweet) => (id: tweet.id, rect: tester.getRect(find.byWidget(tweet))))
      .where((tweet) => tweet.rect.bottom > tester.getRect(find.byType(CustomScrollView)).top);
  final screen = tester.getRect(find.byType(CustomScrollView));
  final starting = shown.where((tweet) => tweet.rect.top >= screen.top && tweet.rect.top < screen.bottom);
  return (starting.isEmpty ? shown : starting).reduce((a, b) => a.rect.top <= b.rect.top ? a : b).id;
}

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());
  useFreshDatabase();

  testWidgets('Should open the feed on the tweet it showed at its top, without loading new tweets', (tester) async {
    final position = _stored[5];
    await _storeFeed(tester, position: position.id);
    final sent = <Uri>[];

    await openFeed(tester, FixtureTwitterClient({}, requestedUris: sent), keepPosition: true);

    expect(_topTweet(tester), position.id, reason: 'The feed should reopen where it was left');
    expect(sent, isEmpty, reason: 'New tweets should only load when the user pulls down');
  });

  testWidgets('Should remember the highest tweet whose top is on the screen once scrolled', (tester) async {
    await _storeFeed(tester);
    await openFeed(tester, FixtureTwitterClient({}), keepPosition: true);

    final tweets = find.byType(TweetConversation);
    // Scrolls until the top of the screen cuts the second tweet
    await tester.drag(tweets.first, Offset(0, 50 - tester.getRect(tweets.at(1)).bottom));
    await settleFeed(tester);

    expect(await _position(tester), _stored[2].id,
        reason: 'The feed should reopen on the first tweet seen whole, not on the one cut by the top of the screen');
  });

  testWidgets('Should remember the tweet at the top of a feed already open when the option is turned on',
      (tester) async {
    await _storeFeed(tester);
    await openFeed(tester, FixtureTwitterClient({}));

    await PrefService.of(tester.element(find.byType(SubscriptionGroupFeed)), listen: false)
        .set(optionKeepFeedOffset, true);
    await tester.pump();
    await tester.drag(find.byType(TweetConversation).first, const Offset(0, -1500));
    await settleFeed(tester);

    expect(await _position(tester), _topTweet(tester),
        reason: 'The option should apply without restarting the app, as the main feed stays open');
  });

  testWidgets('Should scroll back to the newest tweet from the tweet the feed opened on', (tester) async {
    await _storeFeed(tester, position: _stored[5].id);
    final scrollController = FeedScrollController();
    await openFeed(tester, FixtureTwitterClient({}), keepPosition: true, scrollController: scrollController);

    final scrolled = scrollController.scrollToTop(animate: false);
    await settleFeed(tester);
    await scrolled;

    final shownAtTop = tester.state<TweetTileState>(
        find.descendant(of: _tweet(_stored.first), matching: find.byType(TweetTile)).first);
    expect(_topTweet(tester), _stored.first.id, reason: 'Scrolling to the top should not stop on the tweet opened on');
    expect(_stored.first.tweets.map((e) => e.idStr), contains(shownAtTop.tweet.idStr),
        reason: 'The card at the top should show the newest tweet, not the one the feed opened on');
  });
}
