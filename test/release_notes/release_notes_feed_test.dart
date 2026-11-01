import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/release_notes/release_notes.dart';
import 'package:quax/release_notes/release_notes_model.dart';
import 'package:quax/release_notes/release_notes_card.dart';
import 'package:quax/tweet/paginated_tweet_list.dart';

import '../tweet/pump_tweets.dart';
import '../ui/pump_app.dart';

ReleaseNotesModel _updatedTo4201() => ReleaseNotesModel('4.20.1')
  ..update(const [
    ReleaseNote(version: '4.20.1', notes: ['Latest']),
    ReleaseNote(version: '4.20.0', notes: ['Skipped']),
  ]);

Future<TweetPageResult> _noPost(String? cursor) async => (chains: <TweetChain>[], nextCursor: null);

Future<void> _pumpList(WidgetTester tester, ReleaseNotesModel model,
    {required bool refreshable, TweetPageLoader loadPage = _noPost}) async {
  final feed = TweetFeedController();
  addTearDown(feed.dispose);
  await pumpInApp(
      tester,
      withAppModels(Provider.value(
        value: model,
        child: PaginatedTweetList(
          feed: feed,
          loadPage: loadPage,
          username: null,
          onRefresh: refreshable ? () async {} : null,
          firstPageErrorPrefix: (l10n) => 'Unable to load',
          newPageErrorPrefix: (l10n) => 'Unable to load more',
          emptyMessage: 'Nothing here',
        ),
      )),
      settle: false);
  await tester.pump();
}

void main() {
  testWidgets('Should show the notes of the versions installed since the last launch at the top of a feed',
      (tester) async {
    await _pumpList(tester, _updatedTo4201(), refreshable: true);

    expect(find.textContaining('Version 4.20.1', findRichText: true), findsOneWidget, reason: 'The notes of the version installed should be shown');
    expect(find.textContaining('Version 4.20.0', findRichText: true), findsOneWidget, reason: 'The notes of a skipped version should be shown too');
  });

  testWidgets('Should keep showing the notes in a feed rebuilt with a new controller', (tester) async {
    final model = _updatedTo4201();
    await _pumpList(tester, model, refreshable: true);

    await _pumpList(tester, model, refreshable: true);

    expect(find.byType(ReleaseNotesCard), findsOneWidget,
        reason: 'Reloading the subscriptions, as restoring a backup does, rebuilds the feed, which should keep the notes');
  });

  testWidgets('Should not show the notes in search results', (tester) async {
    await _pumpList(tester, _updatedTo4201(), refreshable: false);

    expect(find.byType(ReleaseNotesCard), findsNothing, reason: 'Search results are not a feed');
  });

  testWidgets('Should keep the notes until the refresh replaced the posts', (tester) async {
    final refreshed = Completer<TweetPageResult>();
    var loads = 0;
    await _pumpList(tester, _updatedTo4201(),
        refreshable: true, loadPage: (cursor) => loads++ == 0 ? _noPost(cursor) : refreshed.future);

    await tester.fling(find.text('Nothing here'), const Offset(0, 400), 1000);
    await _pumpFrames(tester);
    final whileRefreshing = find.byType(ReleaseNotesCard).evaluate().length;
    refreshed.complete(await _noPost(null));
    await _pumpFrames(tester);

    expect(whileRefreshing, 1, reason: 'The notes should not vanish before the new posts come, like no other post does');
    expect(find.byType(ReleaseNotesCard), findsNothing, reason: 'The notes should leave with the posts replaced');
  });

  testWidgets('Should keep the notes when the refresh fails', (tester) async {
    var loads = 0;
    await _pumpList(tester, _updatedTo4201(),
        refreshable: true,
        loadPage: (cursor) => loads++ == 0 ? _noPost(cursor) : Future.error(StateError('offline')));

    await tester.fling(find.text('Nothing here'), const Offset(0, 400), 1000);
    await _pumpFrames(tester);

    expect(find.byType(ReleaseNotesCard), findsOneWidget, reason: 'Nothing replaced the posts, so the notes stay');
  });
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
