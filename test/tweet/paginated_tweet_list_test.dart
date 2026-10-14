import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/unrelated_tweets_warning.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/ui/errors.dart';
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

  testWidgets('Should warn about posts from strangers below the error card, without blocking the page',
      (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);

    await pumpInApp(
        tester,
        PaginatedTweetList(
          feed: feed,
          loadPage: (cursor) async {
            feed.partialError.value = PagingError(RateLimitedException(), StackTrace.current);
            feed.containsUnrelatedTweets.value = true;
            return (chains: <TweetChain>[], nextCursor: null);
          },
          username: null,
          firstPageErrorPrefix: (l10n) => 'Unable to load',
          newPageErrorPrefix: (l10n) => 'Unable to load more',
          emptyMessage: 'Nothing here',
        ));

    expect(find.byType(AlertDialog), findsNothing, reason: 'The warning should not interrupt the user');
    expect(find.text('Nothing here'), findsOneWidget, reason: 'The page should render along with the warning');
    expect(tester.getTopLeft(find.byType(UnrelatedTweetsWarning)).dy,
        greaterThan(tester.getTopLeft(find.byType(ErrorCard)).dy),
        reason: 'The warning matters less than the error, so it should come below it');
  });
}
