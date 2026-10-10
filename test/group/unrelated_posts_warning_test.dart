import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/group/unrelated_posts_warning.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/paging.dart';

import '../ui/pump_app.dart';

/// A feed with no post whose first page flags unrelated posts when [warn] is set
PaginatedTweetList feedList(TweetFeedController feed, {bool warn = true}) => PaginatedTweetList(
      feed: feed,
      loadPage: (cursor) async {
        feed.unrelatedPostsWarning.value = warn;
        return (chains: <TweetChain>[], nextCursor: null);
      },
      username: null,
      firstPageErrorPrefix: (l10n) => 'Unable to load',
      newPageErrorPrefix: (l10n) => 'Unable to load more',
      emptyMessage: 'Nothing here',
    );

void main() {
  testWidgets('Should explain the issue with a warning card', (tester) async {
    await pumpInApp(tester, UnrelatedPostsWarningCard(onHide: () {}));

    expect(tester.widget<StatusCard>(find.byType(StatusCard)).level, StatusLevel.warning,
        reason: 'The posts are still shown, so this is a warning and not an error');
    expect(find.text('Feed issue detected'), findsOneWidget, reason: 'The title should name the issue');
    expect(find.widgetWithText(FilledButton, 'More info'), findsOneWidget, reason: 'More info is the primary action');
    expect(find.widgetWithText(TextButton, "Don't show again"), findsOneWidget,
        reason: "Don't show again is the secondary action");
  });

  testWidgets('Should open the issue about unrelated posts on More info', (tester) async {
    final opened = <String>[];
    await pumpInApp(tester, UnrelatedPostsWarningCard(onHide: () {}, open: (_, uri) async => opened.add(uri)));

    await tester.tap(find.text('More info'));

    expect(opened, [unrelatedPostsIssueUri], reason: 'More info should open the issue explaining the problem');
    expect(unrelatedPostsIssueUri, 'https://github.com/Teskann/QuaX/issues/26', reason: 'This is the issue to open');
  });

  testWidgets("Should disable the warnings and hide the card on Don't show again", (tester) async {
    var hidden = false;
    await pumpInApp(tester, UnrelatedPostsWarningCard(onHide: () => hidden = true),
        prefs: {optionDisableWarningsForUnrelatedPostsInFeed: false});

    await tester.tap(find.text("Don't show again"));

    final prefs = PrefService.of(tester.element(find.byType(UnrelatedPostsWarningCard)));
    expect(prefs.get(optionDisableWarningsForUnrelatedPostsInFeed), isTrue, reason: 'The choice should be saved');
    expect(hidden, isTrue, reason: 'The card should go away');
  });

  testWidgets('Should show the warning above the page without blocking it', (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);

    await pumpInApp(tester, feedList(feed));

    expect(find.byType(UnrelatedPostsWarningCard), findsOneWidget, reason: 'The feed flagged unrelated posts');
    expect(find.text('Nothing here'), findsOneWidget, reason: 'The page renders without waiting for the user');
    expect(find.byType(AlertDialog), findsNothing, reason: 'The warning is a card, not a dialog');
  });

  testWidgets("Should hide the warning card after Don't show again", (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    await pumpInApp(tester, feedList(feed));

    await tester.tap(find.text("Don't show again"));
    await tester.pumpAndSettle();

    expect(find.byType(UnrelatedPostsWarningCard), findsNothing, reason: 'The card should be hidden');
    expect(feed.unrelatedPostsWarning.value, isFalse, reason: 'The feed should no longer hold the warning');
  });

  testWidgets('Should show the warning below the error card', (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);
    feed.partialError.value = PagingError(RateLimitedException(), StackTrace.current);

    await pumpInApp(tester, feedList(feed));

    final errorY = tester.getTopLeft(find.byType(ErrorCard)).dy;
    final warningY = tester.getTopLeft(find.byType(UnrelatedPostsWarningCard)).dy;
    expect(warningY, greaterThan(errorY), reason: 'The error matters more, so it comes first');
  });

  testWidgets('Should show no warning when the feed found nothing unrelated', (tester) async {
    final feed = TweetFeedController();
    addTearDown(feed.dispose);

    await pumpInApp(tester, feedList(feed, warn: false));

    expect(find.byType(UnrelatedPostsWarningCard), findsNothing, reason: 'There is nothing to warn about');
  });
}
