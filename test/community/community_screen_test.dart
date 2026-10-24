import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/_header.dart';
import 'package:quax/community/community_model.dart';
import 'package:quax/constants.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/errors.dart';

import '../fixture_client.dart';
import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';
import 'pump_community.dart';

final _shareButton = find.descendant(of: find.byType(CommunityHeader), matching: find.byIcon(Icons.share));

void main() {
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should show the name, the member count and the banner of the community', (tester) async {
    await openCommunity(tester);

    expect(find.byType(ErrorCard), findsNothing, reason: 'The recorded community should load without error');
    expect(find.text(community.name), findsOneWidget,
        reason: 'The header shows the name, the app bar only once the banner is scrolled away');
    final members = NumberFormat.compact(locale: 'en').format(community.memberCount);
    expect(find.textContaining('$members Members', findRichText: true), findsOneWidget,
        reason: 'The header shows how many members the community has');
    expect(find.byType(CommunityBanner), findsOneWidget, reason: 'The recorded community has a banner');
  });

  testWidgets('Should wait for the community before asking for its posts', (tester) async {
    final requested = <String>[];
    await openCommunity(tester,
        client: FixtureTwitterClient({
          'CommunityQuery': recordedCommunity,
          'CommunityTweetsTimeline': recordedPosts(),
        }, requested: requested));

    expect(requested, ['CommunityQuery', 'CommunityTweetsTimeline'],
        reason: 'An empty page shown while the community loads would ask for the posts once more');
  });

  test('Should be loading as soon as the community is asked for', () async {
    Twitter.client = mockOfX();
    final model = CommunityModel(community.id);
    final loading = model.load();

    expect(model.isLoading, isTrue, reason: 'The screen shows a progress indicator, not an empty community, meanwhile');
    await loading;
    model.destroy();
  });

  testWidgets('Should list the Top posts of the community, without a community badge', (tester) async {
    await openCommunity(tester);
    final posts = Twitter.parseCommunityTimeline(recordedPosts().body);

    final shown = tester.widgetList<TweetTile>(find.byType(TweetTile)).map((tile) => tile.tweet.idStr).toList();
    expect(shown, isNotEmpty, reason: 'The Top tab opens first and lists the posts X sent');
    expect(shown.first, posts.chains.first.tweets.first.idStr, reason: 'The posts should keep the order X gives');
    expect(find.byIcon(Icons.groups), findsNothing,
        reason: 'Every post here belongs to this community, so the badge saying so would only repeat itself');
  });

  testWidgets('Should send the bottom cursor to load the next page of posts', (tester) async {
    final uris = <Uri>[];
    await openCommunity(tester,
        client: FixtureTwitterClient({
          'CommunityQuery': recordedCommunity,
          'CommunityTweetsTimeline': recordedPosts(),
        }, requestedUris: uris));
    final firstPage =
        Twitter.parseCommunityTimeline(recordedPosts().body);

    await scrollDownUntil(
        tester, find.byType(NestedScrollView), () => sentVariable(uris, 'CommunityTweetsTimeline', 'cursor').length > 1);

    expect(sentVariable(uris, 'CommunityTweetsTimeline', 'cursor'), [null, firstPage.cursorBottom],
        reason: 'The first page is asked without a cursor, the next one with the bottom cursor of the first');
  });

  testWidgets('Should reload the first page of posts when pulled down', (tester) async {
    final uris = <Uri>[];
    await openCommunity(tester,
        client: FixtureTwitterClient({
          'CommunityQuery': recordedCommunity,
          'CommunityTweetsTimeline': recordedPosts(),
        }, requestedUris: uris));

    await tester.fling(find.byType(NestedScrollView), const Offset(0, 600), 1500);
    await pumpUntilLoaded(tester);
    await tester.pump(const Duration(seconds: 1));

    expect(sentVariable(uris, 'CommunityTweetsTimeline', 'cursor'), [null, null],
        reason: 'Pulling the list down should ask X for the first page again');
  });

  testWidgets('Should show the description, topic, creation date and rules in the About tab', (tester) async {
    await openCommunity(tester);
    await tester.tap(find.text('About'));
    await pumpTransition(tester);

    expect(find.text(community.description!), findsOneWidget, reason: 'About starts with the description');
    expect(find.text(community.topic!), findsOneWidget, reason: 'About shows the topic of the community');
    expect(find.text('Created ${DateFormat.yMMMM('en').format(community.createdAt!)}'), findsOneWidget,
        reason: 'About shows when the community was created');
    for (final rule in community.rules) {
      expect(find.text(rule), findsOneWidget, reason: 'About lists every rule, here "$rule"');
    }
  });

  testWidgets('Should write the rules as large as the description, without spacing the letters', (tester) async {
    await openCommunity(tester, showAbout: true);
    final rule = tester
        .widget<RichText>(find.descendant(of: find.text(community.rules.first), matching: find.byType(RichText)))
        .text
        .style;
    final description = tester.widget<SelectableText>(find.byType(SelectableText)).style;

    expect(rule?.fontSize, description?.fontSize,
        reason: 'A rule should read as easily as the description above it');
    expect(rule?.letterSpacing, 0, reason: 'The letters of a rule should not be spread apart');
  });

  testWidgets('Should open on the About tab from an /about link', (tester) async {
    await openCommunity(tester, showAbout: true);

    expect(find.text(community.rules.first), findsOneWidget,
        reason: 'x.com/i/communities/<id>/about shows the rules, so QuaX should open on About');
    expect(find.byType(TweetTile), findsNothing, reason: 'The posts are in the other tab');
  });

  testWidgets('Should open the banner in full screen when tapped', (tester) async {
    final pushed = await openCommunity(tester);

    await tester.tap(find.byType(CommunityBanner));
    await pumpTransition(tester);

    expect(pushed, hasLength(1), reason: 'Tapping the banner should open one screen');
    expect(find.byType(TweetMediaView), findsOneWidget, reason: 'The banner opens in the media viewer');
  });

  group('Sharing', () {
    final shared = <String?>[];

    setUp(() {
      shared.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
          shareChannel, (call) async {
        shared.add((call.arguments as Map)['text'] as String?);
        return 'dev.fluttercommunity.plus/share/success';
      });
    });

    tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null));

    testWidgets('Should share the x.com link of the community', (tester) async {
      await openCommunity(tester);
      await tester.tap(_shareButton);
      await tester.pump();

      expect(shared, ['https://x.com/i/communities/${community.id}'],
          reason: 'The shared link should open the community on X');
    });

    testWidgets('Should share the link on the site chosen in the settings', (tester) async {
      await openCommunity(tester, prefs: {optionShareBaseUrl: 'https://fxtwitter.com'});
      await tester.tap(_shareButton);
      await tester.pump();

      expect(shared, ['https://fxtwitter.com/i/communities/${community.id}'],
          reason: 'Shared links follow the share site setting, as for posts and profiles');
    });
  });

  testWidgets('Should offer to retry when X sends no community', (tester) async {
    final requested = <String>[];
    await openCommunity(tester,
        client: FixtureTwitterClient({
          'CommunityQuery': Fixture('empty', {
            'body': {'data': {}}
          }),
        }, requested: requested));

    expect(find.byType(FullPageErrorWidget), findsOneWidget, reason: 'A missing community should show an error');
    expect(find.byType(CommunityHeader), findsNothing, reason: 'There is no community to show');

    await tester.tap(find.text('Retry'));
    await pumpUntilLoaded(tester);

    expect(requested.where((operation) => operation == 'CommunityQuery'), hasLength(2),
        reason: 'Retry should ask X for the community again');
  });
}
