import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/utils/rich_text.dart';

import '../tweet/card_fixtures.dart';

const _summaryCardTweet = '2095921351106146703';

Future<String> _shownText(WidgetTester tester, TweetWithCard tweet, {required bool hideCardUrls}) async {
  late List<RichTextPart> parts;
  await tester.pumpWidget(Builder(builder: (context) {
    parts = buildRichText(context, tweet.fullText!, tweet.entities, hideCardUrls: hideCardUrls);
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

  testWidgets('Should keep any other link, even with a card', (tester) async {
    final tweet = detailTweet(_summaryCardTweet);

    expect(await _shownText(tester, tweet, hideCardUrls: true), contains('flutter.dev'),
        reason: 'Only the links to what the card shows are dropped');
  });
}
