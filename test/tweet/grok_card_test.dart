import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/tweet/_carousel_card.dart';
import 'package:quax/tweet/_expandable_tweet_text.dart';
import 'package:quax/tweet/_grok_avatar.dart';
import 'package:quax/tweet/_grok_card.dart';

import '../ui/pump_app.dart';
import 'card_fixtures.dart';

void main() {
  final grok = unifiedOf(detailTweet(grokShareTweet).card!);
  final carousel = unifiedOf(detailTweet(carouselTweet).card!);

  group('GrokShare', () {
    test('Should read the question, the answer and the picture of Grok from the card', () {
      final share = GrokShare.fromUnifiedCard(grok)!;
      final grokUser = grok['component_objects']['details_1']['data']['grok_user'];

      expect(share.question, 'Is this real?', reason: 'The USER message is the question');
      expect(share.answer, startsWith('Yes, the video is real footage'), reason: 'The AGENT message is the answer');
      expect(share.answer, isNot(contains('grok:render')), reason: 'The render markup should be removed from the answer');
      expect(share.uri, grok['destination_objects']['destination_1']['data']['url_data']['url'],
          reason: 'The card should lead to the conversation');
      expect(share.grokImageUrl, grokUser['profile_image_url_https'], reason: 'The picture comes with the card');
      expect(share.grokScreenName, 'grok', reason: 'The avatar should open the profile the card names');
    });

    test('Should fall back to @grok when the card does not name the account', () {
      final card = withUnified(detailTweet(grokShareTweet).card!, (unified) {
        unified['component_objects']['details_1']['data'].remove('grok_user');
      });
      final share = GrokShare.fromUnifiedCard(unifiedOf(card))!;

      expect([share.grokScreenName, share.grokImageUrl], ['grok', null],
          reason: 'Without grok_user the avatar should still open the profile of Grok');
    });

    test('Should give nothing when the conversation or its link is missing', () {
      final withoutPreview = withUnified(detailTweet(grokShareTweet).card!, (unified) {
        unified['component_objects']['details_1']['data'].remove('conversation_preview');
      });
      final withoutDestination = withUnified(detailTweet(grokShareTweet).card!, (unified) {
        unified.remove('destination_objects');
      });

      expect(GrokShare.fromUnifiedCard(unifiedOf(withoutPreview)), isNull,
          reason: 'A card without conversation cannot be drawn');
      expect(GrokShare.fromUnifiedCard(unifiedOf(withoutDestination)), isNull,
          reason: 'A card without destination has nowhere to lead to');
    });
  });

  group('ImageCarouselCard', () {
    test('Should read the page, its title and its images', () {
      final card = ImageCarouselCard.fromUnifiedCard(carousel, 'UEFA')!;

      expect(card.uri, carousel['destination_objects']['browser_1']['data']['url_data']['url'],
          reason: 'The card should lead to the page');
      expect(card.title, contains('Tap to read'), reason: 'The title of the page should be kept');
      expect(card.subtitle, 'uefa.com', reason: 'The site should be kept as the subtitle');
      expect(card.media.length, 4, reason: 'Every image listed by the card should be kept');
    });

    test('Should give nothing when the title is missing', () {
      final card = withUnified(detailTweet(carouselTweet).card!, (unified) {
        unified['component_objects']['details_1']['data'].remove('title');
      });

      expect(ImageCarouselCard.fromUnifiedCard(unifiedOf(card), 'UEFA'), isNull,
          reason: 'A card that cannot be titled falls back to the unsupported card');
    });
  });

  group('GrokAvatar', () {
    testWidgets('Should open the profile of the account the card names when tapped', (tester) async {
      Object? opened;
      await tester.pumpWidget(MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == routeProfile) opened = settings.arguments;
          return MaterialPageRoute(
              builder: (_) => const Scaffold(body: GrokAvatar(imageUrl: null, screenName: 'grok')));
        },
      ));
      await tester.tap(find.byType(GrokAvatar));
      await tester.pump();

      expect((opened as ProfileScreenArguments?)?.screenName, 'grok',
          reason: 'Tapping the picture should open the profile of Grok');
    });
  });

  group('ExpandableTweetText', () {
    testWidgets('Should grow gradually when expanded, not jump', (tester) async {
      final text = List.filled(80, 'a long sentence here.').join(' ');
      await pumpInApp(tester, SingleChildScrollView(child: ExpandableTweetText(textSpans: [TextSpan(text: text)])),
          settle: false);
      final collapsed = tester.getSize(find.byType(ExpandableTweetText)).height;

      await tester.tap(find.text('Show more'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final midway = tester.getSize(find.byType(ExpandableTweetText)).height;
      await tester.pumpAndSettle();
      final expanded = tester.getSize(find.byType(ExpandableTweetText)).height;

      expect(midway, allOf(greaterThan(collapsed), lessThan(expanded)),
          reason: 'The height should be part way through while the text unfolds');
    });
  });
}
