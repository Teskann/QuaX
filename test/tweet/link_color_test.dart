import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/_expandable_tweet_text.dart';
import 'package:quax/tweet/conversation.dart';

import '../fixtures.dart';
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'pump_tweets.dart';

const _postWithEntities = '2095921351106146703';

ColorScheme _scheme(Color seed) => ColorScheme.fromSeed(seedColor: seed);

/// Shows the post under a theme that [scheme] can change while the tile stays on screen.
Future<void> _pumpPost(WidgetTester tester, ValueNotifier<ColorScheme> scheme) async {
  final chains = Twitter.parseTweetDetail(fixture('TweetDetail', _postWithEntities).body).chains;
  await pumpInApp(
      tester,
      withAppModels(ValueListenableBuilder<ColorScheme>(
        valueListenable: scheme,
        builder: (context, colors, child) => Theme(data: ThemeData(colorScheme: colors), child: child!),
        child: SingleChildScrollView(
          child: Column(
            children: chains
                .map((chain) => TweetConversation(id: chain.id, username: null, isPinned: false, tweets: chain.tweets))
                .toList(),
          ),
        ),
      )),
      settle: false);
}

List<({String text, TextStyle style})> _links(WidgetTester tester) {
  final text = tester.widget<ExpandableTweetText>(
      find.descendant(of: tweetTile(_postWithEntities), matching: find.byType(ExpandableTweetText)).first);
  return tappableParts(TextSpan(children: text.textSpans));
}

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should draw the links in the color of the theme loaded after the post', (tester) async {
    final scheme = ValueNotifier(_scheme(Colors.purple));
    await _pumpPost(tester, scheme);

    scheme.value = _scheme(Colors.green);
    await tester.pump();

    expect(_links(tester).map((link) => link.text), ['#QuaXRunes', '@jack', 'flutter.dev'],
        reason: 'The hashtag, the mention and the link of the post should be tappable');
    expect(_links(tester).map((link) => link.style.color), everyElement(scheme.value.primary),
        reason: 'A post already shown should take the new theme color, as after a restart or a theme change');
  });
}
