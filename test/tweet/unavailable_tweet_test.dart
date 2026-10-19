import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/unavailable_tweet.dart';

import '../ui/pump_app.dart';
import 'pump_tweets.dart';

void main() {
  testWidgets('Should say the post is unavailable, with the reason X gives', (tester) async {
    await pumpInApp(tester, const UnavailableTweetCard(reason: 'This Post was deleted by the Post author.'));

    expect(find.text('Post unavailable'), findsOneWidget, reason: 'The title should make the missing post obvious');
    expect(find.text('This Post was deleted by the Post author.'), findsOneWidget,
        reason: 'The reason X gives should be shown as is');
  });

  testWidgets('Should give the likely causes when X says nothing', (tester) async {
    await pumpInApp(tester, const UnavailableTweetCard());

    expect(find.textContaining('probably deleted'), findsOneWidget,
        reason: 'Deleted posts come with no reason, which should not be shown as a blank card');
  });

  testWidgets('Should offer a Web Archive search only when the author is known', (tester) async {
    await pumpInApp(tester, const UnavailableTweetCard(id: '2095934459606376826'));
    expect(find.text('Search Web Archive'), findsNothing,
        reason: 'Captures are listed by the address of the post, which needs its author');

    await pumpInApp(tester, const UnavailableTweetCard(screenName: 'quax_tests', id: '2095934459606376826'));
    expect(find.widgetWithText(TextButton, 'Search Web Archive'), findsOneWidget,
        reason: 'With the author and the id, the captures of the post can be searched');
  });

  testWidgets('Should show a post X sends without any text as unavailable, in a conversation', (tester) async {
    await pumpChains(tester, [
      TweetChain(id: '2105589900078641579', tweets: [TweetWithCard.tombstone(const {})], isPinned: false),
    ]);

    expect(tester.takeException(), isNull, reason: 'A post without text used to fail on its missing text');
    expect(find.byType(UnavailableTweetCard), findsOneWidget, reason: 'The post should read as unavailable');
  });
}
