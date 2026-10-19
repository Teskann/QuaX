import 'package:flutter_test/flutter_test.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';
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
}
