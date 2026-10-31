import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/utils/rich_text.dart';

import '../fixtures.dart';
import '../tweet/card_fixtures.dart';

const _summaryCardTweet = '2095921351106146703';

// A recorded post sharing a space, as AudioSpaceById sends it along with the space
TweetWithCard _spaceTweet() => TweetWithCard.fromGraphqlJson(fixturesOf('AudioSpaceById')
    .map((recorded) => recorded.body['data']?['audioSpace']?['metadata']?['tweet_results']?['result'])
    .whereType<Map<String, dynamic>>()
    .firstWhere((post) => (post['legacy']?['entities']?['urls'] as List? ?? const [])
        .any((url) => '${url['expanded_url']}'.contains('/i/spaces/'))));

Future<String> _shownText(WidgetTester tester, TweetWithCard tweet, {required bool hideCardUrls}) async {
  late List<RichTextPart> parts;
  await tester.pumpWidget(Builder(builder: (context) {
    parts = buildRichText(context, tweet.fullText!, tweet.entities,
        cardUrl: hideCardUrls ? (tweet.card?['url'] as String?) : null);
    return const SizedBox();
  }));
  return TextSpan(children: displayRichText(parts)).toPlainText();
}

void main() {
  final grok = detailTweet(grokShareTweet);

  testWidgets('Should drop the link of a Grok share when a card shows it', (tester) async {
    expect(await _shownText(tester, grok, hideCardUrls: true), isNot(contains('grok/share')),
        reason: 'The conversation is in the card, so its link should not be repeated in the text');
  });

  testWidgets('Should keep the link of a Grok share when no card shows it', (tester) async {
    expect(await _shownText(tester, grok, hideCardUrls: false), contains('x.com/i/grok/share/'),
        reason: 'Without a card, the link is the only way to reach the conversation');
  });

  testWidgets('Should not leave the line break before the link of a Grok share once dropped', (tester) async {
    expect(await _shownText(tester, detailTweet(shortGrokShareTweet), hideCardUrls: true), 'I discussed with Grok today !',
        reason: 'The line break before the dropped link would show as an empty line above the card');
  });

  testWidgets('Should keep any other link, even with a card', (tester) async {
    final tweet = detailTweet(_summaryCardTweet);

    expect(await _shownText(tester, tweet, hideCardUrls: true), contains('flutter.dev'),
        reason: 'Only the links to what the card shows are dropped');
  });

  testWidgets('Should drop the link of a space when its card shows it', (tester) async {
    final tweet = _spaceTweet();

    expect(tweet.entities?.urls?.map((url) => url.expandedUrl), contains(startsWith('https://x.com/i/spaces/')),
        reason: 'The recorded post links to its space');
    expect(await _shownText(tester, tweet, hideCardUrls: true), isNot(contains('/i/spaces/')),
        reason: 'The space is in the card, so its link should not be repeated in the text');
  });

  testWidgets('Should not leave the line breaks after a dropped link that opens the text', (tester) async {
    final tweet = _spaceTweet();
    final link = tweet.entities!.urls!.firstWhere((url) => url.expandedUrl!.contains('/i/spaces/'));
    // As https://x.com/ByBenre/status/2114010308008366271 shares its space
    tweet.fullText = "${link.url}\n\nC'est tout de suite !";
    tweet.entities!.urls = [link..indices = [0, link.url!.length]];

    expect(await _shownText(tester, tweet, hideCardUrls: true), "C'est tout de suite !",
        reason: 'The line breaks after the dropped link would show as empty lines above the text');
  });

  testWidgets('Should keep the link of a space when the card shows another link', (tester) async {
    final tweet = _spaceTweet()..card = {'url': 'https://t.co/another'};

    expect(await _shownText(tester, tweet, hideCardUrls: true), contains('/i/spaces/'),
        reason: 'No card shows this space, so its link is the only way to it');
  });

  testWidgets('Should keep a single gap where a dropped link stood between two paragraphs', (tester) async {
    final tweet = _spaceTweet();
    final link = tweet.entities!.urls!.firstWhere((url) => url.expandedUrl!.contains('/i/spaces/'));
    tweet.fullText = 'Live now\n\n${link.url}\n\n#tag';
    tweet.entities!.urls = [link..indices = [10, 10 + link.url!.length]];
    tweet.entities!.hashtags = [];

    expect(await _shownText(tester, tweet, hideCardUrls: true), 'Live now\n\n#tag',
        reason: 'The gaps before and after the link would show as two empty paragraphs');
  });

  testWidgets('Should show no text when the post is only the link its card shows', (tester) async {
    final tweet = _spaceTweet();
    final link = tweet.entities!.urls!.firstWhere((url) => url.expandedUrl!.contains('/i/spaces/'));
    tweet.fullText = link.url;
    tweet.entities!.urls = [link..indices = [0, link.url!.length]];

    expect(await _shownText(tester, tweet, hideCardUrls: true), isEmpty,
        reason: 'The card says it all, so the post should not keep an empty line above it');
  });
}
