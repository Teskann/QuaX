import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/tweet/_x_tweet_layout.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/user.dart';

import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'card_fixtures.dart';
import 'pump_tweets.dart';

const _pink = Color(0xFFF91880);
const _green = Color(0xFF00BA7C);

TweetWithCard _tweet({
  String id = '100',
  int replyCount = 0,
  int retweetCount = 0,
  int quoteCount = 0,
  int favoriteCount = 0,
  int viewCount = 0,
  bool retweeted = false,
  bool verified = true,
}) =>
    TweetWithCard()
      ..idStr = id
      ..fullText = 'Hello from the X design'
      ..text = 'Hello from the X design'
      ..displayTextRange = [0, 23]
      ..createdAt = DateTime.now().subtract(const Duration(hours: 2))
      ..user = (User()
        ..idStr = '1'
        ..name = 'Ada Lovelace'
        ..screenName = 'ada'
        ..verified = verified)
      ..replyCount = replyCount
      ..retweetCount = retweetCount
      ..quoteCount = quoteCount
      ..favoriteCount = favoriteCount
      ..viewCount = viewCount
      ..retweeted = retweeted;

Future<void> _pumpTile(
  WidgetTester tester,
  TweetWithCard tweet, {
  bool xStyle = true,
  bool hideAuthor = false,
  bool connectTop = false,
  bool connectBottom = false,
  LikedTweetModel? likedModel,
  SavedTweetModel? savedModel,
}) =>
    pumpInApp(
        tester,
        withAppModels(
            SingleChildScrollView(
                child: TweetTile(
                    clickable: true, tweet: tweet, threadConnectTop: connectTop, threadConnectBottom: connectBottom)),
            likedModel: likedModel,
            savedModel: savedModel),
        settle: false,
        prefs: {optionXStyle: xStyle, optionNonConfirmationBiasMode: hideAuthor});

Finder _inActionBar(Finder finder) => find.descendant(of: find.byType(XActionBar), matching: finder);

Finder _connectors() => find.byWidgetPredicate(
    (widget) => widget is Container && widget.constraints?.minWidth == 2 && widget.constraints?.maxWidth == 2);

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  group('Header', () {
    testWidgets('Should read name, handle and time on a single line without any card', (tester) async {
      await _pumpTile(tester, _tweet());

      expect(find.descendant(of: find.byType(TweetTile), matching: find.byType(Card)), findsNothing,
          reason: 'The X design is flat: no card around a tweet');
      final header = find.byType(XTweetHeader);
      final name = find.descendant(of: header, matching: find.text('Ada Lovelace'));
      final details = find.descendant(of: header, matching: find.text(' @ada'));
      expect(name, findsOneWidget, reason: 'The header should name the author');
      expect(details, findsOneWidget, reason: 'The header should show the handle after the name');
      expect(find.descendant(of: header, matching: find.text(' · 2h')), findsOneWidget,
          reason: 'The time should follow the handle after a dot, written short as X does');
      expect(tester.getCenter(name).dy, moreOrLessEquals(tester.getCenter(details).dy, epsilon: 1),
          reason: 'The name and the handle should sit on the same line');
      expect(find.descendant(of: header, matching: find.byIcon(XIcons.verified)), findsOneWidget,
          reason: 'A verified author should get the badge in the header');
    });

    testWidgets('Should leave the badge out of unverified authors', (tester) async {
      await _pumpTile(tester, _tweet(verified: false));

      expect(find.byIcon(XIcons.verified), findsNothing, reason: 'Only verified authors get a badge');
    });

    testWidgets('Should keep only the time when the author is hidden', (tester) async {
      await _pumpTile(tester, _tweet(), hideAuthor: true);

      expect(find.text('Ada Lovelace'), findsNothing, reason: 'The hidden author should not be named');
      expect(find.textContaining('@ada'), findsNothing, reason: 'The hidden author should not show a handle');
      expect(find.byIcon(XIcons.verified), findsNothing, reason: 'The hidden author should not show a badge');
    });

    testWidgets('Should show a 44px avatar next to the content', (tester) async {
      await _pumpTile(tester, _tweet());

      expect(tester.getSize(find.byType(UserAvatar)), const Size(44, 44), reason: 'X avatars are 44px');
      expect(find.text('Hello from the X design'), findsOneWidget, reason: 'The text should be shown');
    });
  });

  group('Action bar', () {
    testWidgets('Should offer the six actions of X', (tester) async {
      await _pumpTile(tester, _tweet());

      for (final icon in [
        XIcons.reply,
        XIcons.repost,
        XIcons.like,
        XIcons.views,
        XIcons.bookmark,
        XIcons.share,
      ]) {
        expect(_inActionBar(find.byIcon(icon)), findsOneWidget, reason: '$icon should be in the action bar');
      }
    });

    testWidgets('Should hide zero counts and abbreviate the others', (tester) async {
      await _pumpTile(tester, _tweet(replyCount: 1200, favoriteCount: 0, retweetCount: 0, viewCount: 0));

      expect(_inActionBar(find.text('1.2K')), findsOneWidget, reason: 'Counts should be abbreviated');
      expect(_inActionBar(find.text('0')), findsNothing, reason: 'A zero count should not be written');
    });

    testWidgets('Should sum reposts and quotes into one count', (tester) async {
      await _pumpTile(tester, _tweet(retweetCount: 3, quoteCount: 4));

      expect(_inActionBar(find.text('7')), findsOneWidget, reason: 'Reposts and quotes should be counted together');
    });

    testWidgets('Should paint a liked tweet with a pink filled heart', (tester) async {
      final liked = LikedTweetModel()..update([LikedTweet(id: '100', user: '1', content: '{}')], force: true);
      await _pumpTile(tester, _tweet(), likedModel: liked);

      expect(tester.widget<Icon>(find.byIcon(XIcons.liked)).color, _pink, reason: 'A liked tweet should be pink');
      expect(find.byIcon(XIcons.like), findsNothing, reason: 'The heart should be filled when liked');
    });

    testWidgets('Should paint a reposted tweet in green', (tester) async {
      await _pumpTile(tester, _tweet(retweeted: true));

      expect(tester.widget<Icon>(_inActionBar(find.byIcon(XIcons.repost))).color, _green,
          reason: 'A reposted tweet should be green');
    });

    testWidgets('Should leave the repost icon grey when the tweet is not reposted', (tester) async {
      await _pumpTile(tester, _tweet());

      expect(tester.widget<Icon>(_inActionBar(find.byIcon(XIcons.repost))).color, isNot(_green),
          reason: 'A tweet not reposted should stay grey');
    });

    testWidgets('Should fill the bookmark of a saved tweet', (tester) async {
      final saved = SavedTweetModel()..update([SavedTweet(id: '100', user: '1', content: '{}', folderId: null)], force: true);
      await _pumpTile(tester, _tweet(), savedModel: saved);

      expect(_inActionBar(find.byIcon(XIcons.bookmarked)), findsOneWidget, reason: 'A saved tweet shows a filled bookmark');
    });
  });

  group('Content', () {
    testWidgets('Should frame the media of a tweet', (tester) async {
      await _pumpTile(tester, detailTweet('2095918742400082069'));

      expect(find.byType(XMediaFrame), findsOneWidget, reason: 'A photo should be framed with rounded corners');
    });

    testWidgets('Should frame the quoted tweet', (tester) async {
      await _pumpTile(tester, detailTweet('2095923354242834733'));

      expect(find.byType(XMediaFrame), findsOneWidget, reason: 'A quoted tweet should be framed');
    });

    testWidgets('Should frame the link card of a tweet', (tester) async {
      await _pumpTile(tester, detailTweet(grokShareTweet));

      expect(find.byType(XMediaFrame), findsOneWidget, reason: 'A link card should be framed');
    });

    testWidgets('Should not frame anything around a plain tweet', (tester) async {
      await _pumpTile(tester, _tweet());

      expect(find.byType(XMediaFrame), findsNothing, reason: 'Without media there is nothing to frame');
    });

    testWidgets('Should announce who reposted with a small repost icon', (tester) async {
      final repost = TweetWithCard()
        ..idStr = '200'
        ..createdAt = DateTime.now()
        ..user = (User()
          ..idStr = '2'
          ..name = 'Grace Hopper'
          ..screenName = 'grace')
        ..retweetedStatusWithCard = _tweet();
      await _pumpTile(tester, repost);

      expect(find.textContaining('Grace Hopper', findRichText: true), findsOneWidget,
          reason: 'The banner should name who reposted');
      final banner = find.byWidgetPredicate((widget) => widget is Icon && widget.icon == XIcons.retweetBanner && widget.size == 16);
      expect(banner, findsOneWidget, reason: 'The banner icon should be 16px');
    });

    testWidgets('Should say "reposted" without any time, aligned with the content column', (tester) async {
      final repost = TweetWithCard()
        ..idStr = '200'
        ..createdAt = DateTime.now().subtract(const Duration(hours: 5))
        ..user = (User()
          ..idStr = '2'
          ..name = 'Grace Hopper'
          ..screenName = 'grace')
        ..retweetedStatusWithCard = _tweet();
      await _pumpTile(tester, repost);

      final text = find.text('Grace Hopper reposted', findRichText: true);
      expect(text, findsOneWidget, reason: 'The banner reads "{name} reposted" and nothing else');
      expect(tester.getTopLeft(text).dx, xTweetContentLeft, reason: 'The text starts at the content column');
      final icon = find.byWidgetPredicate((w) => w is Icon && w.icon == XIcons.retweetBanner && w.size == 16);
      expect(tester.getTopRight(icon).dx, xTweetContentLeft - 4, reason: 'The icon ends 4px before the text');
    });

    testWidgets('Should show who a tweet replies to', (tester) async {
      await _pumpTile(tester, _tweet()..inReplyToScreenName = 'grace');

      expect(find.textContaining('@grace', findRichText: true), findsOneWidget,
          reason: 'The reply line should be kept in the X design');
    });
  });

  group('Threads', () {
    testWidgets('Should draw no connector for a tweet alone', (tester) async {
      await _pumpTile(tester, _tweet());

      expect(_connectors(), findsNothing, reason: 'A lone tweet has no thread line');
      expect(find.byType(XTweetLayout), findsOneWidget, reason: 'The X layout should be used');
    });

    testWidgets('Should link the tweet to the previous and next ones of the thread', (tester) async {
      await _pumpTile(tester, _tweet(), connectTop: true, connectBottom: true);

      expect(_connectors(), findsNWidgets(2), reason: 'The thread line should run above and below the avatar');
      expect(tester.widget<Container>(_connectors().first).color, const Color(0xFFEFF3F4),
          reason: 'The thread line should use the divider color');
    });

    testWidgets('Should only link upward the last tweet of a thread', (tester) async {
      await _pumpTile(tester, _tweet(), connectTop: true);

      expect(_connectors(), findsOneWidget, reason: 'The last tweet is only linked to the previous one');
    });
  });

  group('Regular design', () {
    testWidgets('Should keep the card layout when the X design is off', (tester) async {
      await _pumpTile(tester, _tweet(), xStyle: false);

      expect(find.descendant(of: find.byType(TweetTile), matching: find.byType(Card)), findsOneWidget,
          reason: 'The regular design keeps its card');
      expect(find.byType(XTweetLayout), findsNothing, reason: 'The X layout should stay unused');
      expect(find.byIcon(Icons.mode_comment_outlined), findsOneWidget, reason: 'The regular footer should be kept');
      expect(find.byIcon(Icons.verified), findsOneWidget, reason: 'The regular badge should stay the Material one');
      expect(find.byIcon(XIcons.verified), findsNothing, reason: 'The X icons belong to the X design only');
      expect(find.byIcon(XIcons.reply), findsNothing, reason: 'The regular footer should not use the X icons');
    });
  });
}
