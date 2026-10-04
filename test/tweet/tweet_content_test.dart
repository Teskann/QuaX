import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_card_frame.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/tweet/_photo.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/_video_controls.dart';
import 'package:quax/tweet/conversation.dart';
import 'package:quax/tweet/unavailable_tweet.dart';
import 'package:quax/user.dart';

import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'pump_tweets.dart';

/// Opens the post [id] as recorded in its TweetDetail fixture, checking every
/// reply along the way.
Future<List<TweetChain>> openPost(WidgetTester tester, String id) async {
  final chains = Twitter.parseTweetDetail(fixture('TweetDetail', id).body).chains;
  await pumpChains(tester, chains);
  expectEveryTweetRendered(chains);
  return chains;
}

void expectAuthor(String id, String name, String handle) {
  expect(find.descendant(of: tweetTile(id), matching: find.text(name)), findsWidgets,
      reason: 'The author name should head the tweet');
  expect(find.descendant(of: tweetTile(id), matching: find.text('@$handle')), findsWidgets,
      reason: 'The author handle should head the tweet');
}

void expectMedia(String id, List<String> types, {required double aspectRatio, required WidgetTester tester}) {
  expect(mediaOf(id).map((media) => media.type), types, reason: 'Every media should be shown, in order, with its type');
  expect(mediaAspectRatio(tester, id), moreOrLessEquals(aspectRatio),
      reason: 'The media box should take the ratio of the narrowest media');
  if (types.length > 1) {
    expect(find.descendant(of: tweetTile(id), matching: find.text('1 / ${types.length}')), findsOneWidget,
        reason: 'Several media should show a page counter');
  }
}

Future<List<String>> videoQualities(WidgetTester tester, String id) async {
  final video = tester.widget<TweetVideo>(find.descendant(of: tweetTile(id), matching: find.byType(TweetVideo)));
  final urls = await video.metadata.streamUrlsBuilder();
  return urls.qualities.map((quality) => quality.label).toList();
}

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  group('Text and entities', () {
    testWidgets('Should keep entities in place after emoji made of several code points', (tester) async {
      const id = '2095921351106146703';
      await openPost(tester, id);

      expectAuthor(id, 'QuaX Tests', 'quax_tests');
      expect(visibleText(id), '🧪 fixture · offsets\n👨‍👩‍👧‍👦 🇫🇷 👋🏽 emoji multi-points\n[#QuaXRunes] [@jack] [flutter.dev]\nfin',
          reason: 'Indices count code points, so a shift would cut letters or brackets around the entities');
      expect(links(id), ['#QuaXRunes', '@jack', 'flutter.dev'],
          reason: 'The hashtag, the mention and the link should all be tappable, the link showing its display URL');
      expect(find.text('Flutter - Build apps for any screen'), findsOneWidget,
          reason: 'The summary card should show the page title');
      expect(find.textContaining('Flutter transforms the entire app development process'), findsOneWidget,
          reason: 'The summary card should show the page description');
      expect(find.text('flutter.dev'), findsOneWidget, reason: 'The summary card should show the site');
    });

    testWidgets('Should unescape HTML entities without shifting the entities', (tester) async {
      const id = '2095921599056658635';
      await openPost(tester, id);

      expect(visibleText(id),
          '🧪 fixture · escape\nTom & Jerry <tag> "quotes" \'apostrophe\'\n5 < 7 && 7 > 5\n[#QuaXHtml] [@quax_tests_2 ]',
          reason: 'X escapes &, < and >, which should read as typed, and its indices count the escaped text');
      expect(links(id), ['#QuaXHtml', '@quax_tests_2'], reason: 'Both entities should stay whole and tappable');
    });

    testWidgets('Should keep precomposed, decomposed and compatibility characters as sent', (tester) async {
      const id = '2095922103644028999';
      await openPost(tester, id);

      expect(visibleText(id),
          '🧪 fixture · normalisation\né précomposé vs é décomposé\nﬁ ½ ㍿ Ⅻ ｱ — formes de compatibilité\n[#QuaXNorm]',
          reason: 'X composes the decomposed é itself, and the compatibility forms should not be folded');
      expect(links(id), ['#QuaXNorm'], reason: 'The hashtag after the decomposed é should not be shifted');
    });

    testWidgets('Should show Arabic text with its digits and entities', (tester) async {
      const id = '2095921998094331981';
      await openPost(tester, id);

      expect(visibleText(id), '🧪 fixture · العربية\nمرحبا بالعالم، نص عربي مع [#QuaXAr] و [@jack]\nالأرقام ١٢٣٤٥ داخل النص',
          reason: 'Right-to-left text and Arabic-Indic digits should come through untouched');
      expect(links(id), ['#QuaXAr', '@jack'], reason: 'Entities inside right-to-left text should stay tappable');
    });

    testWidgets('Should show Japanese text with no spaces and a flag emoji', (tester) async {
      const id = '2095921800731345271';
      await openPost(tester, id);

      expect(visibleText(id), '🧪 fixture · 日本語\n日本語のテスト。空白のない文章です。\n絵文字🎌と[#QuaXJa]と[@quax_tests_2]を混ぜます。',
          reason: 'Text without spaces should not lose characters around the entities');
      expect(links(id), ['#QuaXJa', '@quax_tests_2'], reason: 'Entities glued to Japanese text should stay tappable');
    });

    testWidgets('Should show all entity types at once, and link a handle X left without entity', (tester) async {
      const id = '2095922394959421815';
      await openPost(tester, id);

      expect(visibleText(id),
          '🧪 fixture · Full entities\n🎨 quatre ratios différents ci-dessous\n[#QuaXMedia] [@quax_test_2] [flutter.dev]',
          reason: 'The link should show its display URL and the media link should be removed from the text');
      expect(links(id), ['#QuaXMedia', '@quax_test_2', 'flutter.dev'],
          reason: 'QuaX detects mentions in the text itself, so a handle without entity is still linked');
      expectMedia(id, ['photo', 'photo', 'photo', 'photo'], aspectRatio: 900 / 1600, tester: tester);
    });

    testWidgets('Should show a bare tweet, whose entities object is empty', (tester) async {
      const id = '2095912922601975848';
      await openPost(tester, id);

      expectAuthor(id, 'QuaX Tests', 'quax_tests');
      expect(visibleText(id), 'This is a simple tweet', reason: 'An empty entities object should not hide the text');
      expect(links(id), isEmpty, reason: 'A tweet without entities should have nothing to tap');
      expect(mediaOf(id), isEmpty, reason: 'A tweet without media should show none');
    });
  });

  group('Quotes', () {
    testWidgets('Should show a quote with a mention above the quoted tweet', (tester) async {
      const id = '2095923354242834733';
      const quoted = '2095912922601975848';
      await openPost(tester, id);

      expectAuthor(id, 'Moluyts', 'quax_tests_2');
      expect(visibleText(id), 'Quoting\n@quax_tests my friend', reason: 'The quote text should be shown whole');
      expect(links(id), ['@quax_tests'], reason: 'The mention in the quote should be tappable');
      expect(find.descendant(of: tweetTile(id), matching: tweetTile(quoted)), findsOneWidget,
          reason: 'The quoted tweet should be nested in the quote');
      expect(visibleText(quoted), 'This is a simple tweet', reason: 'The quoted tweet should show its own text');
    });

    testWidgets('Should show a quote without entities, and the four videos of the quoted tweet', (tester) async {
      const id = '2095923466830553371';
      const quoted = '2095920215234138129';
      await openPost(tester, id);

      expect(visibleText(id), 'Quiting again', reason: 'The quote text should be shown whole');
      expect(links(id), isEmpty, reason: 'A quote without entities should have nothing to tap');
      expect(visibleText(quoted), '4 videos', reason: 'The quoted tweet should show its own text');
      expect(mediaOf(quoted).map((media) => media.type), ['video', 'video', 'video', 'video'],
          reason: 'The quoted tweet should keep all its videos');
    });

    testWidgets('Should show a quote of a deleted tweet as unavailable', (tester) async {
      const id = '2095934584533680451';
      await openPost(tester, id);

      expect(visibleText(id), 'Quoting a deleted tweet', reason: 'The quote itself should be shown');
      expect(find.descendant(of: tweetTile(id), matching: find.byType(UnavailableTweetCard)), findsOneWidget,
          reason: 'The deleted quoted tweet should be replaced by an unavailable post');
    });

    testWidgets('Should show a quoted tweet with limited replies, unwrapped from its visibility results',
        (tester) async {
      const id = '2095951992489152745';
      const quoted = '2095951850990133591';
      await openPost(tester, id);

      expect(visibleText(id), 'Quoting tweet with limited replies', reason: 'The quote itself should be shown');
      expect(visibleText(quoted), 'Tweet with limited replies @quax_tests_2',
          reason: 'The quoted tweet hides behind TweetWithVisibilityResults, and should still be shown');
      expect(links(quoted), ['@quax_tests_2'], reason: 'The mention of the quoted tweet should be tappable');
      expect(find.byType(UnavailableTweetCard), findsNothing, reason: 'A limited tweet is not a deleted one');
    });
  });

  group('Photos', () {
    for (final (id, scenario, text, ratio) in [
      ('2095918742400082069', 'square', 'Photo 2', 1.0),
      ('2095918809576091964', 'portrait', 'Photo 3', 900 / 1600),
      ('2095918861925163239', 'panoramic', 'Photo 4', 2000 / 800),
    ]) {
      testWidgets('Should show one $scenario photo with its own ratio', (tester) async {
        await openPost(tester, id);

        expect(visibleText(id), text, reason: 'The media link should be removed from the text');
        expectMedia(id, ['photo'], aspectRatio: ratio, tester: tester);
        expect(find.descendant(of: tweetTile(id), matching: find.byType(TweetPhoto)), findsOneWidget,
            reason: 'A photo should be drawn as a photo');
      });
    }

    for (final (id, count, ratio) in [
      ('2095918939641356306', 2, 1.0),
      ('2095919007438139510', 3, 900 / 1600),
      ('2095919075536826410', 4, 900 / 1600),
    ]) {
      testWidgets('Should show $count photos', (tester) async {
        await openPost(tester, id);

        expect(visibleText(id), '$count photos', reason: 'The media link should be removed from the text');
        expectMedia(id, List.filled(count, 'photo'), aspectRatio: ratio, tester: tester);
      });
    }
  });

  group('Videos', () {
    testWidgets('Should show a 16:9 video with its three MP4 qualities', (tester) async {
      const id = '2095919166830084474';
      await openPost(tester, id);

      expect(visibleText(id), 'Video', reason: 'The media link should be removed from the text');
      expectMedia(id, ['video'], aspectRatio: 1280 / 720, tester: tester);
      expect(find.descendant(of: tweetTile(id), matching: find.byType(FritterCenterPlayButton)), findsOneWidget,
          reason: 'A video should wait for a tap to play');
      expect(await videoQualities(tester, id), ['720p', '360p', '270p'],
          reason: 'The MP4 variants, not the HLS playlist, should feed the quality picker, best first');
    });

    for (final (id, scenario, text, ratio) in [
      ('2095919923553775839', 'portrait 9:16', 'Video 2', 720 / 1280),
      ('2095920036523172091', 'square', 'Video 4', 1.0),
    ]) {
      testWidgets('Should show a $scenario video', (tester) async {
        await openPost(tester, id);

        expect(visibleText(id), text, reason: 'The media link should be removed from the text');
        expectMedia(id, ['video'], aspectRatio: ratio, tester: tester);
      });
    }

    testWidgets('Should offer only the two qualities X derives from a 640 by 360 video', (tester) async {
      const id = '2095919982970282273';
      await openPost(tester, id);

      expect(visibleText(id), 'Video 3', reason: 'The media link should be removed from the text');
      expectMedia(id, ['video'], aspectRatio: 640 / 360, tester: tester);
      expect(await videoQualities(tester, id), ['360p', '270p'],
          reason: 'Only the MP4 variants X sends should be offered, without inventing a higher one');
    });

    for (final (id, count, ratio) in [
      ('2095920085445619715', 2, 720 / 1280),
      ('2095920135890506153', 3, 720 / 1280),
      ('2095920215234138129', 4, 720 / 1280),
    ]) {
      testWidgets('Should show $count videos', (tester) async {
        await openPost(tester, id);

        expect(visibleText(id), '$count videos', reason: 'The media link should be removed from the text');
        expectMedia(id, List.filled(count, 'video'), aspectRatio: ratio, tester: tester);
      });
    }

    testWidgets('Should tell photos from videos by their type, not by their URL', (tester) async {
      const id = '2095920289687150903';
      await openPost(tester, id);

      expect(visibleText(id), 'Images and videos', reason: 'The media link should be removed from the text');
      expectMedia(id, ['photo', 'photo', 'video', 'video'], aspectRatio: 720 / 1280, tester: tester);
      expect(find.descendant(of: tweetTile(id), matching: find.byType(TweetPhoto)), findsOneWidget,
          reason: 'The first media is a photo despite its /video/1 URL, so it should be drawn as one');
    });

    testWidgets('Should play an animated GIF on its own, without controls', (tester) async {
      const id = '2095918535159472442';
      await openPost(tester, id);

      expect(visibleText(id), 'Test gif', reason: 'The media link should be removed from the text');
      expectMedia(id, ['animated_gif'], aspectRatio: 1.0, tester: tester);
      final gif = tester.widget<TweetVideo>(find.descendant(of: tweetTile(id), matching: find.byType(TweetVideo)));
      expect(gif.alwaysPlay && gif.loop && gif.disableControls, isTrue,
          reason: 'A GIF should loop by itself with no controls, unlike a video');
    });
  });

  group('Unified cards', () {
    testWidgets('Should show a Grok share as a conversation, without repeating its link in the text', (tester) async {
      const id = '2098507671083036843';
      await openPost(tester, id);

      expect(visibleText(id), '@greg_price11 Troubling',
          reason: 'The link to the conversation is the card itself, so it should not stay in the text');
      expect(find.text('Is this real?'), findsOneWidget, reason: 'The question of the conversation should be shown');
      expect(find.textContaining('Yes, the video is real footage'), findsOneWidget,
          reason: 'The answer of Grok should be shown');
      expect(find.textContaining('<grok:render'), findsNothing, reason: 'The markup inside the answer should be removed');
      expect(find.byType(UserAvatar), findsWidgets, reason: 'The picture of Grok comes with the card');
    });

    testWidgets('Should show an image carousel card with all its images', (tester) async {
      const id = '2082854732020760880';
      await openPost(tester, id);

      expect(mediaOf(id).length, 4, reason: 'The four images of the carousel should be swiped through');
      expect(find.text('uefa.com'), findsOneWidget, reason: 'The card should show the site it leads to');
      final media = find.descendant(of: tweetTile(id), matching: find.byType(TweetMedia));
      final card = find.descendant(of: find.descendant(of: tweetTile(id), matching: find.byType(CardFrame)), matching: find.byType(InkWell));
      expect(tester.getSize(media).width, tester.getSize(card).width,
          reason: 'The images should fill the width of the card, inside its outline');
    });
  });

  group('Polls', () {
    Finder pollShare(String label) => find.ancestor(of: find.text(label), matching: find.byType(Row));

    testWidgets('Should show a poll with two options and its results', (tester) async {
      const id = '2095918053468848131';
      await openPost(tester, id);

      expect(visibleText(id), 'What is your favorite color ?', reason: 'The poll question should be shown');
      expect(find.descendant(of: pollShare('Red').first, matching: find.text('100.0%')), findsOneWidget,
          reason: 'Each option should show its label and its share of the votes');
      expect(find.descendant(of: pollShare('Blue').first, matching: find.text('0.0%')), findsOneWidget,
          reason: 'An option nobody chose should still be shown');
      expect(find.textContaining('One vote', findRichText: true), findsOneWidget,
          reason: 'The total number of votes should be shown');
      expect(find.textContaining('Ended', findRichText: true), findsOneWidget, reason: 'A past poll should say it ended');
    });

    testWidgets('Should show a poll with four options and its results', (tester) async {
      const id = '2095917352416108908';
      await openPost(tester, id);

      expect(visibleText(id), 'This is the poll with 4 choices', reason: 'The poll question should be shown');
      final shares = {'opt 1': '0.0%', 'opt 2': '100.0%', 'opt 3': '0.0%', 'opt 4': '0.0%'};
      for (final MapEntry(key: label, value: share) in shares.entries) {
        expect(find.descendant(of: pollShare(label).first, matching: find.text(share)), findsOneWidget,
            reason: 'Every option should show its label and share: $label');
      }
    });
  });

  group('Threads and deleted posts', () {
    testWidgets('Should show a thread in order, X leaving out its deleted tweet', (tester) async {
      const replies = ['This was not removed', 'The next tweet will be removed', 'This one is not removed', 'Great'];
      const ids = ['2095916387017408802', '2095916388829303123', '2095916392784572662', '2095916394722295934'];
      final chains = await openPost(tester, '2095916385209651546');

      expect(visibleText('2095916385209651546'), 'Test thread with tombstone', reason: 'The opened post should be shown');
      expect(chains.last.tweets.map((tweet) => tweet.idStr), ids,
          reason: 'The replies should form one thread, in the order they were posted');
      expect(ids.map(visibleText), replies, reason: 'Every remaining reply should show its text');
      final tops = ids.map((id) => tester.getTopLeft(tweetTile(id)).dy).toList();
      expect(tops, orderedEquals([...tops]..sort()), reason: 'The replies should be drawn from oldest to newest');
      expect(find.textContaining('Thread', findRichText: true), findsOneWidget, reason: 'The replies should be labelled as a thread');
      expect(find.byType(UnavailableTweetCard), findsNothing,
          reason: 'X sends nothing for the deleted reply, so there is nothing to show in its place');
    });

    testWidgets('Should show a deleted post opened directly as unavailable', (tester) async {
      const id = '2095934459606376826';
      await pumpScreen(tester, const StatusScreen(),
          arguments: StatusScreenArguments(id: id, username: 'quax_tests'),
          fixtures: {'TweetDetail': fixture('TweetDetail', id)});

      expect(find.byType(UnavailableTweetCard), findsOneWidget,
          reason: 'X answers with an empty entry, which should read as an unavailable post');
      expect(find.text('Post unavailable'), findsOneWidget, reason: 'The card should say the post is unavailable');
      expect(find.byType(TweetConversation), findsNothing, reason: 'There is no tweet to draw');
    });
  });

  testWidgets('Should show a subscriber-only post opened directly as its preview', (tester) async {
    const id = '2105589900078641579';
    await pumpScreen(tester, const StatusScreen(),
        arguments: StatusScreenArguments(id: id, username: 'Osemka8'),
        fixtures: {'TweetDetail': fixture('TweetDetail', id)});

    expect(find.descendant(of: tweetTile(id), matching: find.byType(UnavailableTweetCard)), findsNothing,
        reason: 'X sends the preview of the post, which is not a deleted post');
    expect(visibleText(id), "I know I've written about this for you guys, but c…",
        reason: 'The beginning of the post X sends should be shown');
    expect(find.descendant(of: tweetTile(id), matching: find.text('Post reserved for subscribers of @Osemka8')),
        findsOneWidget,
        reason: 'The preview should say why the post is cut, and whose subscribers can read it');
    expect(
        find.descendant(
            of: find.byType(UnavailableTweetCard), matching: find.text("Post reserved for the author's subscribers")),
        findsOneWidget,
        reason: 'X hides the reply of the author entirely (ExclusiveTweet), which should not be called deleted');
  });

  testWidgets('Should show the community note under the tweet it is written for', (tester) async {
    const id = '2026390853309063292';
    final chains = await openPost(tester, id);
    final note = chains.first.tweets.first.birdwatchQuotedStatus?.text ?? '';

    expectAuthor(id, 'The Labour Party', 'UKLabour');
    expect(visibleText(id),
        '🚨BREAKING: new poll suggests there is just one point between Labour and Reform in Gorton and Denton.\n\n'
        'Every vote will count on Thursday. Back Labour and choose unity over Reform’s division.',
        reason: 'The tweet text should be shown, without its media link');
    expectMedia(id, ['photo'], aspectRatio: 1638 / 2048, tester: tester);
    expect(find.descendant(of: tweetTile(id), matching: find.textContaining('Users added context', findRichText: true)), findsOneWidget,
        reason: 'The community note should be headed as such');
    expect(
        find.descendant(
            of: tweetTile(id), matching: find.textContaining(note.substring(0, note.length.clamp(0, 40)))),
        findsOneWidget,
        reason: 'The note text, read from birdwatch_pivot.subtitle, should be shown');
    expect(note, isNotEmpty, reason: 'The note should be read from birdwatch_pivot.subtitle');
  });
}
