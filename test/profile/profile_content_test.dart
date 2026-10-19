import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/profile/_follows.dart';
import 'package:quax/profile/_media_grid.dart';
import 'package:quax/profile/_tweets.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/_video_controls.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';

const quaxTestsId = '2095909295913103360';
const quaxTests2Id = '2095914123905118211';
const osemkaId = '3864149734';
const subscribersOnly = 'Post reserved for subscribers of @Osemka8';

int _counter = 0;

/// A profile view as the app parses it.
List<TweetChain> profileTimeline(String operation, String name) => Twitter.createUnconversationedChains(
      fixture(operation, name).body,
      'tweet',
      const [],
      false,
      true,
      true,
      () => _counter,
      () => _counter++,
    ).chains;

UserWithExtra userOf(String screenName) =>
    Twitter.parseProfile(fixture('UserByScreenName', screenName).body, 'https://x.com/$screenName').user;

/// Opens a profile on its posts tab. The header sizes itself from measured
/// parts and overflows by a pixel with the test font: layout is not what these
/// tests check, so overflow reports are dropped while the profile is drawn.
Future<void> openProfile(WidgetTester tester, String fixtureName, String screenName, String timeline) async {
  final onError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exceptionAsString().contains('overflowed')) onError?.call(details);
  };
  try {
    await pumpScreen(
      tester,
      const ProfileScreen(),
      arguments: ProfileScreenArguments.fromScreenName(screenName, null),
      fixtures: {
        'UserByScreenName': fixture('UserByScreenName', fixtureName),
        'UserTweets': fixture('UserOriginalsTimeline', timeline),
      },
    );
  } finally {
    FlutterError.onError = onError;
  }
}

/// Shows a profile tab under the state the profile screen gives it.
Future<void> openTab(WidgetTester tester, Widget Function(BasePrefService prefs) tab, Map<String, Fixture> fixtures) =>
    pumpScreen(
        tester,
        ChangeNotifierProvider(
            create: (_) => TweetContextState(true),
            child: Builder(builder: (context) => tab(PrefService.of(context, listen: false)))),
        arguments: const Object(),
        fixtures: fixtures);

Finder bannerOf(String userId) => find.byWidgetPredicate((widget) =>
    widget is ExtendedImage &&
    widget.image is ExtendedNetworkImageProvider &&
    (widget.image as ExtendedNetworkImageProvider).url.contains('profile_banners/$userId'));

Finder headerText(Finder finder) => find.descendant(of: find.byType(FlexibleSpaceBar), matching: finder);

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  group('Profile header', () {
    testWidgets('Should show a full profile: avatar, banner, bio with two links and a bare mention', (tester) async {
      await openProfile(tester, 'quax-tests', 'quax_tests', quaxTestsId);

      expect(headerText(find.text('QuaX Tests')), findsOneWidget, reason: 'The display name should head the profile');
      expect(headerText(find.text('@quax_tests')), findsOneWidget, reason: 'The handle should follow the name');
      expect(bannerOf(quaxTestsId), findsOneWidget, reason: 'The banner, read outside the legacy block, should be shown');
      expect(tester.widget<UserAvatar>(headerText(find.byType(UserAvatar))).uri, contains('YjqaAMdO'),
          reason: 'The avatar, read outside the legacy block, should be shown');
      final bio = tester.widget<SelectableText>(headerText(find.byType(SelectableText)));
      expect(bio.textSpan!.toPlainText(),
          '🧪 Throwaway account · QuaX parsing fixtures 🇫🇷\n  Nothing real, every post is a test case.\n'
          '  github.com/Teskann/QuaX · flutter.dev\n  Ping @jack',
          reason: 'The bio should show its links by their display URL, after emoji that shift the indices');
      final tappable = <String>[];
      bio.textSpan!.visitChildren((span) {
        if (span is TextSpan && span.recognizer != null) tappable.add(span.text!);
        return true;
      });
      expect(tappable, ['github.com/Teskann/QuaX', 'flutter.dev', '@jack'],
          reason: 'Both links should be tappable, and the mention too although X gives it no entity');
      expect(headerText(find.text('India')), findsOneWidget, reason: 'The location should be shown');
      expect(headerText(find.textContaining('0 followers', findRichText: true)), findsOneWidget,
          reason: 'The follower count should be shown');
      expect(find.byType(TweetTile), findsWidgets, reason: 'The posts tab should list the posts of the profile');
    });

    testWidgets('Should show a bare profile: default avatar, no banner, empty bio, zero followers', (tester) async {
      await openProfile(tester, 'quax-tests-2', 'quax_tests_2', quaxTests2Id);

      expect(headerText(find.text('Moluyts')), findsOneWidget, reason: 'The display name should head the profile');
      expect(headerText(find.text('@quax_tests_2')), findsOneWidget, reason: 'The handle should follow the name');
      expect(tester.widget<UserAvatar>(headerText(find.byType(UserAvatar))).uri, contains('default_profile'),
          reason: 'The default avatar X assigns should be shown');
      expect(bannerOf(quaxTests2Id), findsNothing, reason: 'A profile without banner should not try to load one');
      expect(headerText(find.byType(SelectableText)), findsNothing, reason: 'An empty bio should take no room');
      expect(headerText(find.textContaining('0 followers', findRichText: true)), findsOneWidget,
          reason: 'Zero followers should still be shown as a count');
      expect(find.byType(TweetTile), findsWidgets, reason: 'The posts tab should list the posts of the profile');
    });

    testWidgets('Should open a profile whose posts include subscriber-only previews', (tester) async {
      await openProfile(tester, 'osemka8', 'Osemka8', osemkaId);

      expect(find.byType(ErrorCard), findsNothing, reason: 'Subscriber-only previews used to fail the whole timeline');
      expect(headerText(find.text('@Osemka8')), findsOneWidget, reason: 'The profile should be shown');
      expect(find.byType(TweetTile), findsWidgets, reason: 'The posts tab should list the posts of the profile');
    });

    testWidgets('Should say an unknown handle does not exist', (tester) async {
      await pumpScreen(tester, const ProfileScreen(),
          arguments: ProfileScreenArguments.fromScreenName('ce_pseudo_nexiste_pas_quax', null),
          fixtures: {'UserByScreenName': fixture('UserByScreenName', 'ce-pseudo-nexiste-pas-quax')});

      expect(find.byType(ErrorCard), findsOneWidget,
          reason: 'X answers {"data": {}} without errors, which should still end in an error');
      expect(find.textContaining('User not found'), findsWidgets, reason: 'The error should say the user does not exist');
    });
  });

  group('Follows', () {
    for (final (operation, type, message) in [
      ('Followers', 'followers', 'This user does not have anyone following them!'),
      ('Following', 'following', 'This user does not follow anyone!'),
    ]) {
      testWidgets('Should say when the $type list is empty', (tester) async {
        await openTab(tester, (_) => ProfileFollows(user: userOf('quax-tests'), type: type),
            {operation: fixture(operation, quaxTestsId)});

        expect(find.text(message), findsOneWidget, reason: 'An empty list should say so rather than stay blank');
        expect(find.byType(ErrorCard), findsNothing, reason: 'An empty list is not an error');
      });
    }
  });

  group('Profile views', () {
    testWidgets('Should show the replies tab with its threads, the next page being empty', (tester) async {
      final chains = profileTimeline('UserRepliesTimeline', quaxTestsId);
      await pumpChains(tester, chains);

      expectEveryTweetRendered(chains);
      expect(chains.where((chain) => chain.tweets.length > 1), isNotEmpty,
          reason: 'The replies tab is where threads come from');
      expect(find.textContaining('Thread', findRichText: true), findsWidgets,
          reason: 'A thread should be labelled as such');
      expect(profileTimeline('UserRepliesTimeline', '$quaxTestsId-page2'), isEmpty,
          reason: 'The last page holds no tweet and should not fail');
    });

    testWidgets('Should show every video of the media tab in the grid', (tester) async {
      await openTab(tester, (prefs) => ProfileMediaGrid(user: userOf('quax-tests'), pref: prefs),
          {'UserMedia': fixture('UserVideoTimeline', quaxTestsId)});

      expect(find.byType(FritterCenterPlayButton), findsNWidgets(4),
          reason: 'X sends the four videos of the account, each should be a grid cell with a play button');
    });

    testWidgets('Should say the media tab of an account without media is empty', (tester) async {
      await openTab(tester, (prefs) => ProfileMediaGrid(user: userOf('quax-tests-2'), pref: prefs),
          {'UserMedia': fixture('UserVideoTimeline', quaxTests2Id)});

      expect(find.text("Couldn't find any posts by this user!"), findsOneWidget,
          reason: 'An empty media tab should say so rather than stay blank');
    });

    testWidgets('Should say the replies tab of an account that only quoted is empty', (tester) async {
      await openTab(
          tester,
          (prefs) => ProfileTweets(
              user: userOf('quax-tests-2'), type: 'profile', includeReplies: true, pinnedTweets: const [], pref: prefs),
          {'UserTweetsAndReplies': fixture('UserRepliesTimeline', quaxTests2Id)});

      expect(find.text("Couldn't find any posts by this user!"), findsOneWidget,
          reason: 'An empty replies tab should say so rather than stay blank');
    });

    testWidgets('Should show reposts with who reposted them', (tester) async {
      final chains = profileTimeline('UserRepostsTimeline', quaxTests2Id);
      await pumpChains(tester, chains);

      expectEveryTweetRendered(chains);
      expect(tweetsOf(chains).where((tweet) => tweet.retweetedStatusWithCard != null), isNotEmpty,
          reason: 'This view is the only place a retweeted_status_result shows up');
      expect(find.textContaining('Moluyts reposted', findRichText: true), findsWidgets,
          reason: 'A repost should name the account that reposted it');
    });

    testWidgets('Should show no repost for an account that has none', (tester) async {
      final chains = profileTimeline('UserRepostsTimeline', quaxTestsId);
      await pumpChains(tester, chains);

      expect(chains, isEmpty, reason: 'An account without reposts should yield no tweet, and no failure');
    });

    testWidgets('Should show posts, reposts and replies of the quieter account', (tester) async {
      final chains = profileTimeline('UserTweetsAndReplies', quaxTests2Id);
      await pumpChains(tester, chains);

      expectEveryTweetRendered(chains);
      expect(tweetsOf(chains), isNotEmpty, reason: 'The All view should list the posts of the account');
    });

    testWidgets('Should show the four-video and mixed-media posts in the All view', (tester) async {
      final chains = profileTimeline('UserTweetsAndReplies', quaxTestsId);
      await pumpChains(tester, chains);

      expectEveryTweetRendered(chains);
      expect(mediaOf('2095920215234138129').map((media) => media.type), ['video', 'video', 'video', 'video'],
          reason: 'The four-video post should keep its four videos in a timeline');
      expect(mediaOf('2095920289687150903').map((media) => media.type), ['photo', 'photo', 'video', 'video'],
          reason: 'The mixed post should tell photos from videos in a timeline too');
    });

    testWidgets('Should show subscriber-only previews as truncated posts marked as such', (tester) async {
      const preview = '2105589900078641579';
      final chains = profileTimeline('UserOriginalsTimeline', osemkaId);
      await pumpChains(tester, chains);

      expectEveryTweetRendered(chains);
      expect(visibleText(preview), "I know I've written about this for you guys, but c…",
          reason: 'X only sends the beginning of a subscriber-only post, which should be shown as is');
      expect(find.descendant(of: tweetTile(preview), matching: find.text(subscribersOnly)), findsOneWidget,
          reason: 'A preview should say why the post is cut');
      expect(find.text(subscribersOnly), findsNWidgets(7),
          reason: 'All seven previews should be marked, those inside threads included, and only them');
      expect(chains.where((chain) => chain.tweets.length > 1), isNotEmpty,
          reason: 'Threads of the posts tab, named profile-originals-conversation, should be kept');
    });

    for (final (scenario, name) in [
      ('Most recent', quaxTestsId),
      ('Popular', '$quaxTestsId-c36f6d'),
    ]) {
      testWidgets('Should show the posts of the profile sorted by $scenario', (tester) async {
        final chains = profileTimeline('UserOriginalsTimeline', name);
        await pumpChains(tester, chains);

        expectEveryTweetRendered(chains);
        expect(tweetsOf(chains), isNotEmpty, reason: 'The profile timeline should list its posts');
      });
    }
  });
}
