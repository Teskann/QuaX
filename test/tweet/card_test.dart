import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/tweet/_card.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/user.dart';

import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'card_fixtures.dart';
import 'pump_tweets.dart';

/// The address and the name of each call the platform receives from the card: links opened, browser asked for.
class _PlatformSpy {
  final urls = <String>[];
  var browserAsked = false;

  _PlatformSpy() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
      urls.add((call.arguments as Map)['url'] as String);
      return true;
    });
    messenger.setMockMethodCallHandler(const MethodChannel('browser_resolver'), (call) async {
      browserAsked = true;
      return 'com.android.chrome';
    });
    messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), (call) async => {
          'appName': 'QuaX',
          'packageName': 'com.teskann.quax',
          'version': '1.2.3',
          'buildNumber': '1',
        });
  }
}

/// Draws the card of [tweet], or [card] when a copy of it was broken on purpose.
Future<void> _pumpCard(WidgetTester tester, TweetWithCard tweet,
        {Map<String, dynamic>? card, Map<String, dynamic> prefs = const {}}) =>
    pumpInApp(tester, withAppModels(SingleChildScrollView(child: TweetCard(tweet: tweet, card: card ?? tweet.card))),
        settle: false, prefs: prefs);

void expectUnsupported(String reason) =>
    expect(find.textContaining("isn't supported yet"), findsOneWidget, reason: reason);

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  final grok = detailTweet(grokShareTweet);
  final carousel = detailTweet(carouselTweet);
  final grokUnified = unifiedOf(grok.card!);
  final carouselUnified = unifiedOf(carousel.card!);

  group('Unified cards', () {
    testWidgets('Should show every image of a carousel card, with its page', (tester) async {
      await _pumpCard(tester, carousel);

      final expected = (carouselUnified['component_objects']['swipeable_media_1']['data']['media_list'] as List)
          .map((item) => carouselUnified['media_entities'][item['id']]['id_str']);
      expect(tester.widget<TweetMedia>(find.byType(TweetMedia)).media.map((media) => media.idStr), expected,
          reason: 'Each image of the carousel should be swiped through, in the order the card lists them');
      expect(find.textContaining('Tap to read'), findsOneWidget, reason: 'The card should show its title');
      expect(find.text('uefa.com'), findsOneWidget, reason: 'The card should show the site it leads to');
    });

    testWidgets('Should read a carousel card as X sends it, binding values in a list', (tester) async {
      await _pumpCard(tester, carousel, card: rawCard(carouselTweet));

      expect(find.byType(TweetMedia), findsOneWidget, reason: 'The list form of binding values should be understood');
    });

    testWidgets('Should show a Grok share as the question and the answer, without the markup of the answer',
        (tester) async {
      await _pumpCard(tester, grok);

      expect(find.text('Is this real?'), findsOneWidget, reason: 'The question of the conversation should be shown');
      expect(find.textContaining('Yes, the video is real footage', findRichText: true), findsOneWidget,
          reason: 'The answer of Grok should be shown');
      expect(find.textContaining('grok:render', findRichText: true), findsNothing,
          reason: 'The markup X puts in the answer should be removed');
    });

    testWidgets('Should show the picture of Grok from the card', (tester) async {
      await _pumpCard(tester, grok);

      expect(find.byType(UserAvatar), findsOneWidget, reason: 'The card carries the picture of Grok');
    });

    testWidgets('Should keep an icon where the picture of Grok goes when the card has none', (tester) async {
      final card = withUnified(cardOf(grok), (unified) {
        unified['component_objects']['details_1']['data'].remove('grok_user');
      });
      await _pumpCard(tester, grok, card: card);

      expect(find.byIcon(Icons.auto_awesome), findsOneWidget, reason: 'There should be no hole where the picture goes');
    });

    testWidgets('Should let the long answer of a Grok share be expanded', (tester) async {
      await _pumpCard(tester, grok);

      expect(find.text('Show more'), findsOneWidget, reason: 'A truncated answer should offer to show the rest');
      await tester.tap(find.text('Show more'));
      await tester.pump();
      expect(find.text('Show more'), findsNothing, reason: 'Once expanded, the answer should not offer more');
    });

    testWidgets('Should cope with a Grok share that has no answer', (tester) async {
      final card = withUnified(cardOf(grok), (unified) {
        final data = unified['component_objects']['details_1']['data'];
        data['conversation_preview'] = (data['conversation_preview'] as List).take(1).toList();
      });
      await _pumpCard(tester, grok, card: card);

      expect(tester.takeException(), isNull, reason: 'A missing answer should not fail the card');
      expect(find.text('Is this real?'), findsOneWidget, reason: 'The question should still be shown');
    });

    testWidgets('Should show an image website card with its page', (tester) async {
      final tweet = homeTweet(imageWebsiteTweet);
      await _pumpCard(tester, tweet);

      expect(find.text('Le test est gratuit. La consultation des résultats est payante.'), findsOneWidget,
          reason: 'The title of the page should be shown');
      expect(find.text('wwiqtest.com'), findsOneWidget, reason: 'The site it leads to should be shown');
    });
  });

  group('Opening links', () {
    testWidgets('Should open the conversation when a Grok share is tapped', (tester) async {
      final spy = _PlatformSpy();
      await _pumpCard(tester, grok);
      await tester.tap(find.text('Is this real?'));

      expect(spy.urls, [grokUnified['destination_objects']['destination_1']['data']['url_data']['url']],
          reason: 'The card should lead to the shared conversation');
    });

    testWidgets('Should open the conversation when the answer of a Grok share is tapped', (tester) async {
      final spy = _PlatformSpy();
      await _pumpCard(tester, grok);
      await tester.tap(find.textContaining('Yes, the video is real footage', findRichText: true));

      expect(spy.urls, hasLength(1), reason: 'Selecting text should not stop the card from opening');
    });

    testWidgets('Should open the page of a carousel when its title is tapped', (tester) async {
      final spy = _PlatformSpy();
      await _pumpCard(tester, carousel);
      await tester.ensureVisible(find.textContaining('Tap to read'));
      await tester.tap(find.textContaining('Tap to read'));

      expect(spy.urls, [carouselUnified['destination_objects']['browser_1']['data']['url_data']['url']],
          reason: 'The card should lead to the page it advertises');
    });

    testWidgets('Should open the page of an image website card when tapped', (tester) async {
      final spy = _PlatformSpy();
      final tweet = homeTweet(imageWebsiteTweet);
      await _pumpCard(tester, tweet);
      await tester.ensureVisible(find.text('wwiqtest.com'));
      await tester.tap(find.text('wwiqtest.com'));

      expect(spy.urls, [unifiedOf(tweet.card!)['destination_objects']['browser_1']['data']['url_data']['url']],
          reason: 'The card should lead to the page');
    });

    testWidgets('Should offer to report an unsupported card with the link of its tweet', (tester) async {
      final spy = _PlatformSpy();
      await _pumpCard(tester, grok, card: {...cardOf(grok), 'name': 'brand_new_card'});
      await tester.tap(find.widgetWithText(FilledButton, 'Report'));
      await tester.pump();

      expect(Uri.parse(spy.urls.single).queryParameters['title'],
          contains('https://x.com/elonmusk/status/$grokShareTweet'),
          reason: 'The issue should name the tweet whose card cannot be drawn');
    });

    testWidgets('Should open the tweet in the browser from an unsupported card', (tester) async {
      final spy = _PlatformSpy();
      await _pumpCard(tester, grok, card: {...cardOf(grok), 'name': 'brand_new_card'});
      await tester.tap(find.widgetWithText(TextButton, 'Open in browser'));
      await tester.pump();

      expect(spy.browserAsked, isTrue, reason: 'The tweet should be opened in the default browser of the phone');
    });
  });

  group('Unsupported cards', () {
    testWidgets('Should say a card of an unknown name is not supported', (tester) async {
      await _pumpCard(tester, grok, card: {...cardOf(grok), 'name': 'brand_new_card'});

      expectUnsupported('A card QuaX cannot draw should say so instead of vanishing');
      expect(find.widgetWithText(FilledButton, 'Report'), findsOneWidget,
          reason: 'The card should offer to report the problem');
      expect(find.widgetWithText(TextButton, 'Open in browser'), findsOneWidget,
          reason: 'The card should offer to read the post on X');
    });

    testWidgets('Should say a unified card of an unknown type is not supported', (tester) async {
      final card = withUnified(cardOf(carousel), (unified) => unified['type'] = 'something_new');
      await _pumpCard(tester, carousel, card: card);

      expectUnsupported('An unknown unified type should not render as a blank');
    });

    testWidgets('Should say a typeless unified card that is not a Grok share is not supported', (tester) async {
      final card = withUnified(cardOf(grok), (unified) {
        unified['component_objects']['details_1']['type'] = 'something_new';
      });
      await _pumpCard(tester, grok, card: card);

      expectUnsupported('A card without type nor known component should be reported as unsupported');
    });

    testWidgets('Should say a Grok share without destination is not supported', (tester) async {
      final card = withUnified(cardOf(grok), (unified) => unified.remove('destination_objects'));
      await _pumpCard(tester, grok, card: card);

      expectUnsupported('A conversation that cannot be opened should fall back to the unsupported card');
    });

    testWidgets('Should say a carousel without destination is not supported', (tester) async {
      final card = withUnified(cardOf(carousel), (unified) => unified.remove('destination_objects'));
      await _pumpCard(tester, carousel, card: card);

      expect(tester.takeException(), isNull, reason: 'A missing destination should not throw');
      expectUnsupported('A carousel that cannot be opened should fall back to the unsupported card');
    });

    testWidgets('Should say a carousel whose images are unknown is not supported', (tester) async {
      final card = withUnified(cardOf(carousel), (unified) => unified['media_entities'] = {});
      await _pumpCard(tester, carousel, card: card);

      expectUnsupported('A carousel with no image to show should fall back to the unsupported card');
    });

    testWidgets('Should say a carousel without title is not supported', (tester) async {
      final card = withUnified(cardOf(carousel), (unified) {
        unified['component_objects']['details_1']['data'].remove('title');
      });
      await _pumpCard(tester, carousel, card: card);

      expectUnsupported('A carousel that cannot be titled should fall back to the unsupported card');
    });

    testWidgets('Should say a unified card without payload is not supported', (tester) async {
      await _pumpCard(tester, grok, card: {...cardOf(grok), 'binding_values': {}});

      expectUnsupported('A unified card whose payload is missing should be reported as unsupported');
    });
  });

  group('Poll cards', () {
    Finder imageOf(String url) => find.byWidgetPredicate(
        (w) => w is ExtendedImage && w.image is ExtendedNetworkImageProvider && (w.image as ExtendedNetworkImageProvider).url == url);

    testWidgets('Should show the choices of an image poll with their picture and results', (tester) async {
      await _pumpCard(tester, grok, card: imagePollCard());

      expect(find.text('Choice 1'), findsOneWidget, reason: 'The first choice should show its label');
      expect(find.text('Choice 2'), findsOneWidget, reason: 'The second choice should show its label');
      expect(find.text('75.0%'), findsOneWidget, reason: 'The leading choice should show its share of the votes');
      expect(find.text('25.0%'), findsOneWidget, reason: 'The other choice should show its share of the votes');
      expect(find.textContaining('Ended', findRichText: true), findsOneWidget, reason: 'A past poll should say it ended');
      expect(find.byType(ExtendedImage), findsNWidgets(2), reason: 'Only the 2 choices of the poll should have a picture');
    });

    testWidgets('Should use the small picture of each choice', (tester) async {
      await _pumpCard(tester, grok, card: imagePollCard());

      expect(imageOf('https://pbs.twimg.com/card_img/1_small.jpg'), findsOneWidget,
          reason: 'The thumbnail of the first choice should be the small picture');
      expect(imageOf('https://pbs.twimg.com/card_img/2_small.jpg'), findsOneWidget,
          reason: 'The thumbnail of the second choice should be the small picture');
    });

    testWidgets('Should show an image poll of four choices', (tester) async {
      await _pumpCard(tester, grok, card: imagePollCard(choices: 4));

      for (var i = 1; i <= 4; i++) {
        expect(find.text('Choice $i'), findsOneWidget, reason: 'The choice $i of 4 should be shown');
      }
      expect(find.byType(ExtendedImage), findsNWidgets(4), reason: 'Each of the 4 choices should have a picture');
    });

    testWidgets('Should say an image poll is still running when it ends in the future', (tester) async {
      final endsAt = DateTime.now().add(const Duration(days: 2)).toUtc().toIso8601String();
      await _pumpCard(tester, grok, card: imagePollCard(endsAt: endsAt));

      expect(find.textContaining('Ends', findRichText: true), findsOneWidget,
          reason: 'A poll that is not over should say when it ends');
      expect(find.textContaining('Ended', findRichText: true), findsNothing, reason: 'The poll is not over yet');
    });

    testWidgets('Should read an image poll whose name has no id prefix', (tester) async {
      await _pumpCard(tester, grok, card: imagePollCard(name: 'poll_choice_images'));

      expect(find.text('Choice 1'), findsOneWidget, reason: 'The name alone should be enough to find an image poll');
    });

    testWidgets('Should not take a card whose name only looks like an image poll for one', (tester) async {
      await _pumpCard(tester, grok, card: imagePollCard(name: '12:poll_choice_images_v2'));

      expectUnsupported('Only the exact poll_choice_images name, after an optional id, is an image poll');
    });

    for (final count in [null, 'abc', '', '1', '5']) {
      testWidgets('Should say an image poll with choice_count $count is not supported', (tester) async {
        final card = imagePollCard(edit: (values) {
          count == null ? values.remove('choice_count') : values['choice_count'] = {'string_value': count};
        });
        await _pumpCard(tester, grok, card: card);

        expectUnsupported('The number of choices cannot be guessed, so the card should not be drawn');
      });
    }

    testWidgets('Should keep the label of a choice that has no picture', (tester) async {
      final card = imagePollCard(edit: (values) {
        values.removeWhere((key, _) => key.startsWith('choice2_image'));
      });
      await _pumpCard(tester, grok, card: card);

      expect(find.text('Choice 2'), findsOneWidget, reason: 'A choice without picture should still be shown');
      expect(find.byType(ExtendedImage), findsOneWidget, reason: 'Only the choice with a picture should show one');
    });

    testWidgets('Should fall back on the full picture when the small one is missing', (tester) async {
      final card = imagePollCard(edit: (values) => values.remove('choice1_image_small'));
      await _pumpCard(tester, grok, card: card);

      expect(imageOf('https://pbs.twimg.com/card_img/1.jpg'), findsOneWidget,
          reason: 'The picture of the choice should still be found without its small version');
    });

    testWidgets('Should keep the label of a choice whose picture has no address', (tester) async {
      final card = imagePollCard(edit: (values) => values['choice1_image_small'] = {'type': 'IMAGE'});
      await _pumpCard(tester, grok, card: card);

      expect(find.text('Choice 1'), findsOneWidget, reason: 'A picture without address should not hide the choice');
      expect(find.byType(ExtendedImage), findsOneWidget, reason: 'Only the second choice has a usable picture');
    });

    testWidgets('Should not load the pictures of an image poll when images are disabled', (tester) async {
      await _pumpCard(tester, grok, card: imagePollCard(), prefs: {optionImageQuality: 'disabled'});

      expect(find.text('Choice 1'), findsOneWidget, reason: 'The choices should be shown without their pictures');
      expect(find.byType(ExtendedImage), findsNothing, reason: 'Disabled images should not be downloaded');
    });

    testWidgets('Should say an image poll without label for a choice is not supported', (tester) async {
      final card = imagePollCard(edit: (values) => values.remove('choice2_label'));
      await _pumpCard(tester, grok, card: card);

      expectUnsupported('An incomplete image poll should fall back on the unsupported card, not crash');
    });

    testWidgets('Should say an image poll without end date is not supported', (tester) async {
      final card = imagePollCard(edit: (values) => values.remove('end_datetime_utc'));
      await _pumpCard(tester, grok, card: card);

      expectUnsupported('An image poll without end date should fall back on the unsupported card, not crash');
    });

    testWidgets('Should say an image poll without binding values is not supported', (tester) async {
      await _pumpCard(tester, grok, card: {...imagePollCard(), 'binding_values': null});

      expectUnsupported('An image poll without binding values should be reported as unsupported');
    });

    for (final choices in [2, 3, 4]) {
      testWidgets('Should still show a text poll of $choices choices without pictures', (tester) async {
        await _pumpCard(tester, grok, card: textPollCard(choices: choices));

        for (var i = 1; i <= choices; i++) {
          expect(find.text('Text $i'), findsOneWidget, reason: 'The choice $i of the text poll should be shown');
        }
        expect(find.byType(ExtendedImage), findsNothing, reason: 'A text poll has no picture');
        expect(find.text({2: '75.0%', 3: '60.0%', 4: '50.0%'}[choices]!), findsOneWidget,
            reason: 'The leading choice should show its share of the votes');
      });
    }
  });
}
