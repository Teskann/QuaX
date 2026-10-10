import 'dart:io';

import 'package:dart_twitter_api/twitter_api.dart' show User;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/home/x_account_model.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_x_tweet_layout.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';
import '../home/x_pump.dart' show fakeAccountModel;
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'pump_tweets.dart';

final _postedAt = DateTime(2026, 9, 5, 15, 45);

TweetWithCard _tweet({int? views = 1200}) => TweetWithCard()
  ..idStr = '100'
  ..fullText = 'Hello from the X design'
  ..text = 'Hello from the X design'
  ..displayTextRange = [0, 23]
  ..createdAt = _postedAt
  ..user = (User()
    ..idStr = '1'
    ..name = 'Ada Lovelace'
    ..screenName = 'ada'
    ..verified = true)
  ..replyCount = 3
  ..favoriteCount = 5
  ..viewCount = views;

Future<void> _pumpTile(WidgetTester tester, {bool focal = true, bool xStyle = true, TweetWithCard? tweet}) =>
    pumpInApp(
        tester,
        withAppModels(SingleChildScrollView(
            child: TweetTile(clickable: true, tweet: tweet ?? _tweet(), isFocal: focal, tweetOpened: true))),
        settle: false,
        prefs: {optionXStyle: xStyle});

String _detailsLine(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((e) => e.text.toPlainText())
    .firstWhere((e) => e.contains('Views'));

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  group('Focal post', () {
    testWidgets('Should put the author on top: 44px avatar, name with badge, handle and translate button',
        (tester) async {
      await _pumpTile(tester);

      expect(find.byType(XFocalTweetLayout), findsOneWidget, reason: 'The opened post has its own layout');
      expect(find.byType(XTweetLayout), findsNothing, reason: 'It does not use the layout of the timeline');
      expect(tester.getSize(find.byType(UserAvatar)), const Size(44, 44), reason: 'The avatar is 44px');
      final name = tester.widget<Text>(find.text('Ada Lovelace')).style!;
      expect([name.fontSize, name.fontWeight], [16, FontWeight.w700], reason: 'The name is 16 w700');
      expect(find.byIcon(XIcons.verified), findsOneWidget, reason: 'The verified author gets the badge');
      final handle = tester.widget<Text>(find.text('@ada')).style!;
      expect(handle.fontSize, 15, reason: 'The handle is 15px');
      expect(handle.color, XStyleColors.light.secondaryText, reason: 'The handle is secondary');
      expect(tester.getTopLeft(find.text('@ada')).dy, greaterThan(tester.getBottomLeft(find.text('Ada Lovelace')).dy - 1),
          reason: 'The handle is under the name');
      expect(find.byIcon(XIcons.translate), findsOneWidget, reason: 'The translate button stays on the right');
      expect(tester.getTopRight(find.byIcon(XIcons.translate)).dx, greaterThan(tester.getSize(find.byType(XFocalTweetLayout)).width - 40),
          reason: 'The translate button is at the end of the row');
    });

    testWidgets('Should lay the text under the author on the full width, at 17px with a 1.35 line height',
        (tester) async {
      await _pumpTile(tester);

      final text = find.text('Hello from the X design');
      expect(tester.getTopLeft(text).dx, 16, reason: 'The text is not indented under the avatar');
      expect(tester.getSize(text).height, moreOrLessEquals(17 * 1.35, epsilon: 0.5), reason: 'The line is 17px at 1.35');
      expect(tester.getTopLeft(text).dy, greaterThan(tester.getBottomLeft(find.byType(UserAvatar)).dy),
          reason: 'The text starts under the avatar');
    });

    testWidgets('Should keep the text of a post of the timeline indented under the avatar', (tester) async {
      await _pumpTile(tester, focal: false);

      expect(find.byType(XFocalTweetLayout), findsNothing, reason: 'A post that is not opened keeps the tile');
      expect(tester.getTopLeft(find.text('Hello from the X design')).dx, xTweetContentLeft,
          reason: 'The text of a regular tile starts at the content column');
    });

    testWidgets('Should write when and how many times it was seen, with the count in bold', (tester) async {
      await _pumpTile(tester);

      expect(_detailsLine(tester), '${xFocalTimestamp(_postedAt)} · 1.2K Views',
          reason: 'The line is time, date and views, separated by dots');
      expect(xFocalTimestamp(_postedAt, locale: 'en'), contains('Sep 5, 2026'), reason: 'The date is month, day, year');
      expect(xFocalTimestamp(_postedAt, locale: 'en'), contains('3:45'), reason: 'The time has no leading zero');
      final root = tester
          .widgetList<RichText>(find.byType(RichText))
          .firstWhere((e) => e.text.toPlainText().contains('Views'))
          .text as TextSpan;
      final line = root.children!.single as TextSpan;
      expect(line.style!.fontSize, 15, reason: 'The line is 15px');
      expect(line.style!.color, XStyleColors.light.secondaryText, reason: 'The line is secondary');
      final count = line.children!.whereType<TextSpan>().firstWhere((e) => e.text == '1.2K');
      expect(count.style!.fontWeight, FontWeight.w700, reason: 'The number of views is bold');
      expect(count.style!.color, XStyleColors.light.primaryText, reason: 'The number of views is in primary text');
    });

    testWidgets('Should leave out the views when X did not tell them', (tester) async {
      await _pumpTile(tester, tweet: _tweet(views: null));

      expect(find.textContaining('Views', findRichText: true), findsNothing, reason: 'No count, no views');
      expect(find.textContaining('Sep 5, 2026', findRichText: true), findsOneWidget, reason: 'The date stays');
    });

    testWidgets('Should spread the 22px actions between two dividers on the full width', (tester) async {
      await _pumpTile(tester);

      final layout = find.byType(XFocalTweetLayout);
      expect(find.descendant(of: layout, matching: find.byType(Divider)), findsNWidgets(2),
          reason: 'One divider above the actions and one below');
      expect(tester.widgetList<Divider>(find.byType(Divider)).map((e) => e.height), [1, 1],
          reason: 'Dividers are 1px');
      expect(tester.widget<Icon>(find.byIcon(XIcons.reply)).size, 22, reason: 'Action icons are 22px');
      expect(tester.widget<Icon>(find.byIcon(XIcons.share)).size, 22, reason: 'Every action icon is 22px');
      expect(tester.getTopLeft(find.byIcon(XIcons.reply)).dx, 16, reason: 'The first action starts at the margin');
      final width = tester.getSize(layout).width;
      expect(tester.getTopRight(find.byIcon(XIcons.share)).dx, moreOrLessEquals(width - 16 - 4, epsilon: 1),
          reason: 'The last action ends at the margin');
      final xs = [XIcons.reply, XIcons.repost, XIcons.like, XIcons.views]
          .map((icon) => tester.getCenter(find.byIcon(icon)).dx)
          .toList();
      expect(xs[1] - xs[0], greaterThan(60), reason: 'The actions are spread, not packed on the left');
    });

    testWidgets('Should draw the regular action bar when the post is not opened', (tester) async {
      await _pumpTile(tester, focal: false);

      expect(tester.widget<Icon>(find.byIcon(XIcons.reply)).size, 18, reason: 'Timeline icons stay 18px');
    });

    testWidgets('Should keep the regular design when the X design is off', (tester) async {
      await _pumpTile(tester, xStyle: false);

      expect(find.byType(XFocalTweetLayout), findsNothing, reason: 'The focal layout belongs to the X design');
    });
  });

  group('Post screen', () {
    const id = '2095916385209651546';
    final fixtures = {'TweetDetail': fixture('TweetDetail', id)};

    Future<void> openScreen(WidgetTester tester, {bool xStyle = true}) => pumpScreen(tester, const StatusScreen(),
        arguments: StatusScreenArguments(id: id, username: 'quax_tests'),
        fixtures: fixtures,
        prefs: {optionXStyle: xStyle},
        aboveApp: (app) => Provider<XAccountModel>.value(value: fakeAccountModel(), child: app));

    testWidgets('Should title the app bar "Post", 19px extra bold and on the left', (tester) async {
      await openScreen(tester);

      final title = tester.widget<Text>(find.descendant(of: find.byType(AppBar), matching: find.text('Post')));
      expect([title.style!.fontSize, title.style!.fontWeight], [19, FontWeight.w800], reason: 'The title is 19 w800');
      expect(tester.getTopLeft(find.text('Post')).dx, lessThan(40), reason: 'The title is left aligned');
    });

    testWidgets('Should lay out only the opened post as the focal one and keep the tiles of the replies',
        (tester) async {
      await openScreen(tester);

      final tiles = tester.widgetList<TweetTile>(find.byType(TweetTile)).toList();
      expect(tiles.where((e) => e.isFocal).map((e) => e.tweet.idStr), [id], reason: 'Only the opened post is focal');
      expect(find.byType(XFocalTweetLayout), findsOneWidget, reason: 'One post has the focal layout');
      expect(find.byType(XTweetLayout), findsWidgets, reason: 'The replies keep the tile of the timeline');
    });

    testWidgets('Should have no reply composer, since QuaX cannot post', (tester) async {
      await openScreen(tester);

      expect(find.byType(TextField), findsNothing, reason: 'Replying happens in X, not in a bar at the bottom');
      expect(find.text('Post your reply'), findsNothing, reason: 'The composer is gone');
    });

    testWidgets('Should keep the regular app bar outside the X design', (tester) async {
      await openScreen(tester, xStyle: false);

      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Post')), findsNothing,
          reason: 'The regular design has no title there');
      expect(find.byType(XFocalTweetLayout), findsNothing, reason: 'The regular design has no focal layout');
    });
  });
}
