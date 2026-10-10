import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/x_overlay_feed.dart';
import 'package:quax/utils/paging.dart';

import '../ui/pump_app.dart';

void main() {
  testWidgets('Should show the part of a page that could not be loaded above the tweets', (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);

    await pumpInApp(
        tester,
        PaginatedTweetList(
          feed: feed,
          loadPage: (cursor) async {
            feed.partialError.value = PagingError(RateLimitedException(), StackTrace.current);
            return (chains: <TweetChain>[], nextCursor: null);
          },
          username: null,
          firstPageErrorPrefix: (l10n) => 'Unable to load',
          newPageErrorPrefix: (l10n) => 'Unable to load more',
          emptyMessage: 'Nothing here',
        ));

    expect(find.widgetWithText(ErrorCard, 'Rate limited by 𝕏'), findsOneWidget,
        reason: 'Searches that were rate limited should be reported above what the other searches loaded');
    expect(find.text('Nothing here'), findsOneWidget,
        reason: 'A partial failure should not replace the page, which still shows what was loaded');
  });

  group('Under a header laid over the feed', () {
    Future<void> pumpList(WidgetTester tester, {double? inset}) async {
      final feed = TweetFeedController();
      addTearDown(feed.dispose);
      Widget list = PaginatedTweetList(
        feed: feed,
        loadPage: (cursor) async => (chains: <TweetChain>[], nextCursor: null),
        username: null,
        onRefresh: () async {},
        firstPageErrorPrefix: (l10n) => 'Unable to load',
        newPageErrorPrefix: (l10n) => 'Unable to load more',
        emptyMessage: 'Nothing here',
      );
      if (inset != null) list = XHeaderInset(inset: inset, child: list);
      await pumpInApp(tester, list);
    }

    testWidgets('Should pull the refresh spinner down to the bottom of the header', (tester) async {
      await pumpList(tester, inset: 96);

      expect(tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).edgeOffset, 96,
          reason: 'The spinner must not be hidden by the header');
    });

    testWidgets('Should show the cards above the tweets below the header, not under it', (tester) async {
      final feed = TweetFeedController();
      addTearDown(feed.dispose);
      await pumpInApp(
          tester,
          XHeaderInset(
              inset: 96,
              child: PaginatedTweetList(
                feed: feed,
                loadPage: (cursor) async {
                  feed.partialError.value = PagingError(RateLimitedException(), StackTrace.current);
                  return (chains: <TweetChain>[], nextCursor: null);
                },
                username: null,
                firstPageErrorPrefix: (l10n) => 'Unable to load',
                newPageErrorPrefix: (l10n) => 'Unable to load more',
                emptyMessage: 'Nothing here',
              )));

      final card = find.byType(ErrorCard);
      final scaffoldTop = tester.getTopLeft(find.byType(PaginatedTweetList)).dy;
      expect(tester.getTopLeft(card).dy - scaffoldTop, greaterThanOrEqualTo(96),
          reason: 'A card hidden by the header cannot be read nor tapped');
      expect(tester.getTopLeft(find.text('Nothing here')).dy, greaterThan(tester.getBottomLeft(card).dy),
          reason: 'The tweets should follow right after the card, without the header inset a second time');
    });

    testWidgets('Should keep the spinner at the top when no header is laid over the feed', (tester) async {
      await pumpList(tester);

      expect(tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).edgeOffset, 0,
          reason: 'The regular design is unchanged');
    });
  });
}
