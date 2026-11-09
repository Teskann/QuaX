import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/dates.dart';

import '../fixtures.dart';
import 'pump_tweets.dart';
import '../ui/pump_app.dart';

List<TweetChain> _recordedLatestPosts() =>
    Twitter.parseSearchTimeline(fixture('SearchTimeline', 'from-quax-tests').body).chains;

String _shownTime(WidgetTester tester, TweetTile tile) => tester
    .widget<Text>(
      find
          .descendant(
            of: find.byWidget(tile),
            matching: find.descendant(of: find.byType(Timestamp), matching: find.byType(Text)),
          )
          .first,
    )
    .data!;

void main() {
  testWidgets('Should show the time of each post after a refresh brought a newer one on top', (tester) async {
    final posts = _recordedLatestPosts();
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    // Posted weeks before the first one
    final olderPosts = posts.skip(4).toList();
    var refreshed = false;

    await pumpInApp(
      tester,
      withAppModels(
        PaginatedTweetList(
          feed: feed,
          loadPage: (cursor) async => (chains: [if (refreshed) posts.first, ...olderPosts], nextCursor: null),
          username: null,
          firstPageErrorPrefix: (l10n) => 'Unable to load',
          newPageErrorPrefix: (l10n) => 'Unable to load more',
          emptyMessage: 'Nothing here',
        ),
      ),
      settle: false,
      prefs: {optionUseAbsoluteTimestamp: true},
    );
    await tester.pump(const Duration(seconds: 1));

    refreshed = true;
    await feed.softRefresh();
    await tester.pump(const Duration(seconds: 1));

    final tiles = tester.widgetList<TweetTile>(find.byType(TweetTile)).toList();
    expect(tiles, isNotEmpty, reason: 'The refreshed posts should be shown');
    for (final tile in tiles) {
      expect(
        _shownTime(tester, tile),
        absoluteDateFormat.format(tile.tweet.createdAt!.toLocal()),
        reason: 'Post ${tile.tweet.idStr} should show its own time, not the one of the post shown there before',
      );
    }
  });
}
