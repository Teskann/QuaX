import 'dart:io';

import 'package:flutter/gestures.dart';
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

/// The tappable parts of [span] with the color each is drawn in, the parents' color passing to their children.
Iterable<MapEntry<String, Color?>> _tappableColors(InlineSpan span, Color? inherited) {
  final color = span.style?.color ?? inherited;
  if (span is! TextSpan) return const [];
  return [
    if (span.recognizer is TapGestureRecognizer) MapEntry(span.text ?? '', color),
    ...?span.children?.expand((child) => _tappableColors(child, color)),
  ];
}

Map<String, Color?> _linkColors(WidgetTester tester) {
  final text = tester.widget<ExpandableTweetText>(
      find.descendant(of: tweetTile(_postWithEntities), matching: find.byType(ExpandableTweetText)).first);
  return Map.fromEntries(text.textSpans.expand((span) => _tappableColors(span, null)));
}

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should draw the links in the color of the theme loaded after the post', (tester) async {
    final scheme = ValueNotifier(_scheme(Colors.purple));
    await _pumpPost(tester, scheme);

    scheme.value = _scheme(Colors.green);
    await tester.pump();

    expect(_linkColors(tester).keys, ['#QuaXRunes', '@jack', 'flutter.dev'],
        reason: 'The hashtag, the mention and the link of the post should be tappable');
    expect(_linkColors(tester).values, everyElement(scheme.value.primary),
        reason: 'A post already shown should take the new theme color, as after a restart or a theme change');
  });
}
