import 'package:dart_twitter_api/twitter_api.dart' show Media;
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/tweet/_expandable_tweet_text.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/tweet/tweet_context_scope.dart';
import 'package:quax/tweet/video_controller_pool.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../ui/pump_app.dart';

/// Wraps [child] with the models tweet tiles and profiles read, as the app does.
Widget withAppModels(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ImportDataModel()),
        Provider(create: (_) => LikedTweetModel()),
        Provider(create: (_) => SavedTweetModel()),
        Provider(create: (_) => VideoControllerPool(maxSize: 2)),
        Provider(create: (context) => GroupsModel(PrefService.of(context, listen: false))),
        Provider(
            create: (context) =>
                SubscriptionsModel(PrefService.of(context, listen: false), context.read<GroupsModel>())),
      ],
      child: TweetContextScope(child: child),
    );

/// Renders every chain the way a timeline does, all built at once so that
/// tweets far down the list can be inspected too.
Future<void> pumpChains(WidgetTester tester, List<TweetChain> chains) => pumpInApp(
      tester,
      withAppModels(SingleChildScrollView(
        child: Column(
          children: chains
              .map((chain) => TweetConversation(
                  id: chain.id, username: null, isPinned: chain.isPinned, tweets: chain.tweets))
              .toList(),
        ),
      )),
      settle: false,
    );

/// The tile of the tweet [id]. A tweet both shown and quoted has two tiles, the
/// first one being the tweet itself.
Finder tweetTile(String id) => find.byWidgetPredicate((w) => w is TweetTile && w.tweet.idStr == id).first;

/// Elements of type [T] drawn by the tile of [id] itself, not by a tweet it quotes.
Iterable<Element> _ownElements<T extends Widget>(String id) =>
    find.descendant(of: tweetTile(id), matching: find.byType(T)).evaluate().where((element) {
      final tile = element.findAncestorWidgetOfExactType<TweetTile>();
      return tile?.tweet.idStr == id;
    });

List<InlineSpan> _textSpans(String id) {
  final texts = _ownElements<ExpandableTweetText>(id);
  return texts.isEmpty ? const [] : (texts.first.widget as ExpandableTweetText).textSpans;
}

/// The text of the tweet [id] as it reads on screen, without the blank that a
/// trailing media link leaves once removed.
String visibleText(String id) => TextSpan(children: _textSpans(id)).toPlainText().trimRight();

/// The parts of the tweet [id] that react to a tap: hashtags, mentions and links.
List<String> links(String id) {
  final tappable = <String>[];
  for (final span in _textSpans(id)) {
    span.visitChildren((child) {
      if (child is TextSpan && child.recognizer is TapGestureRecognizer) {
        tappable.add(child.text ?? '');
      }
      return true;
    });
  }
  return tappable;
}

/// The media attached to the tweet [id], in the order they are shown.
List<Media> mediaOf(String id) {
  final media = _ownElements<TweetMedia>(id);
  return media.isEmpty ? const [] : (media.first.widget as TweetMedia).media;
}

/// The aspect ratio the media box of the tweet [id] reserves.
double mediaAspectRatio(WidgetTester tester, String id) => tester
    .widget<AspectRatio>(find
        .descendant(of: find.descendant(of: tweetTile(id), matching: find.byType(TweetMedia)), matching: find.byType(AspectRatio))
        .first)
    .aspectRatio;

/// Every [TweetChain] tweet, threads flattened.
List<TweetWithCard> tweetsOf(List<TweetChain> chains) => chains.expand((chain) => chain.tweets).toList();

/// Opens [screen] as a route carrying [arguments], answering its requests with
/// [fixtures] keyed by GraphQL operation, then lets the pages load.
Future<void> pumpScreen(WidgetTester tester, Widget screen,
    {required Object arguments, required Map<String, Fixture> fixtures}) async {
  Twitter.client = FixtureTwitterClient(fixtures);
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await pumpInApp(
      tester,
      withAppModels(Navigator(
        onGenerateRoute: (_) =>
            MaterialPageRoute(builder: (_) => screen, settings: RouteSettings(arguments: arguments)),
      )),
      settle: false);
  await pumpUntilLoaded(tester);
}

/// Draws enough frames for the requests a screen chains to complete.
Future<void> pumpUntilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The texts a tweet should make tappable, read from its entities.
List<String> _entityLinks(TweetWithCard tweet) {
  final entities = tweet.noteEntities ?? tweet.entities;
  return [
    ...?entities?.hashtags?.map((hashtag) => '#${hashtag.text}'),
    ...?entities?.userMentions?.map((mention) => '@${mention.screenName}'),
    ...?entities?.urls?.map((url) => url.displayUrl ?? ''),
  ];
}

/// What every tweet of a timeline should get right, whatever its content.
void expectEveryTweetRendered(List<TweetChain> chains) {
  for (final tweet in tweetsOf(chains).where((tweet) => tweet.isTombstone != true)) {
    final id = tweet.idStr!;
    final shown = tweet.retweetedStatusWithCard ?? tweet;
    expect(find.descendant(of: tweetTile(id), matching: find.text('@${shown.user?.screenName}')), findsWidgets,
        reason: 'Tweet $id should show the handle of its author');
    expect(visibleText(id), isNot(matches(RegExp('&(amp|lt|gt);'))),
        reason: 'Tweet $id should read with its HTML entities unescaped');
    expect(visibleText(id), isNot(contains('https://t.co/')),
        reason: 'Tweet $id should show links by their display URL, and drop the media link');
    expect(links(id), containsAll(_entityLinks(shown)),
        reason: 'Every hashtag, mention and link of tweet $id should be tappable');
    expect(mediaOf(id).length, shown.extendedEntities?.media?.length ?? 0,
        reason: 'Tweet $id should show all its media');
    if (tweet.retweetedStatusWithCard != null) {
      expect(find.descendant(of: tweetTile(id), matching: find.textContaining('reposted', findRichText: true)),
          findsOneWidget,
          reason: 'Repost $id should say who reposted it');
    }
  }
}
