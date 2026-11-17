import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';

import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'pump_tweets.dart';

const _postWithLink = '2095921351106146703';

RenderEditable _textOf(WidgetTester tester, String id) => _editableIn(
      tester.renderObject(find.descendant(of: tweetTile(id), matching: find.byType(EditableText)).first),
    )!;

/// The middle of [text] in the text of the post [id].
Offset _centerOf(WidgetTester tester, String id, String text) {
  final editable = _textOf(tester, id);
  final start = editable.text!.toPlainText().indexOf(text);
  final box = editable.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + text.length)).first;
  return editable.localToGlobal(box.toRect().center);
}

RenderEditable? _editableIn(RenderObject node) {
  if (node is RenderEditable) return node;
  RenderEditable? found;
  node.visitChildren((child) => found ??= _editableIn(child));
  return found;
}

/// The background drawn behind the link showing [shown] in the text of the post [id].
Color? _backgroundOfLink(WidgetTester tester, String id, String shown) =>
    tappableParts(_textOf(tester, id).text!).firstWhere((link) => link.text == shown).style.backgroundColor;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should copy a link with a long press on it', (tester) async {
    final chains = Twitter.parseTweetDetail(fixture('TweetDetail', _postWithLink).body).chains;
    final link = tweetsOf(chains).firstWhere((tweet) => tweet.idStr == _postWithLink).entities!.urls!.single;
    String? copied;
    final platformCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call.method);
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    await pumpChains(tester, chains);

    await tester.longPressAt(_centerOf(tester, _postWithLink, link.displayUrl!));
    await tester.pump();

    expect(copied, link.expandedUrl, reason: 'The full link should be copied, not the shortened one shown');
    expect(find.text('Select all'), findsNothing, reason: 'The long press should copy the link, not select text');
    expect(platformCalls, contains('HapticFeedback.vibrate'), reason: 'The phone should vibrate, as for any long press');
  });

  testWidgets('Should highlight a link only while it is pressed', (tester) async {
    final chains = Twitter.parseTweetDetail(fixture('TweetDetail', _postWithLink).body).chains;
    final link = tweetsOf(chains).firstWhere((tweet) => tweet.idStr == _postWithLink).entities!.urls!.single;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async => null);
    await pumpChains(tester, chains);

    final gesture = await tester.startGesture(_centerOf(tester, _postWithLink, link.displayUrl!));
    await tester.pump(kLongPressTimeout ~/ 2);
    expect(_backgroundOfLink(tester, _postWithLink, link.displayUrl!), isNotNull,
        reason: 'The pressed link should be highlighted, so the user sees which one they hit');

    await tester.pump(kLongPressTimeout);
    expect(_backgroundOfLink(tester, _postWithLink, link.displayUrl!), isNotNull,
        reason: 'The link should stay highlighted while it is copied by the long press');

    await gesture.up();
    await tester.pump();
    expect(_backgroundOfLink(tester, _postWithLink, link.displayUrl!), isNull,
        reason: 'The highlight should go once the finger is lifted');
  });
  testWidgets('Should highlight a hashtag or a mention only while it is pressed', (tester) async {
    final chains = Twitter.parseTweetDetail(fixture('TweetDetail', _postWithLink).body).chains;
    await pumpChains(tester, chains);

    for (final shown in ['#QuaXRunes', '@jack']) {
      final gesture = await tester.startGesture(_centerOf(tester, _postWithLink, shown));
      await tester.pump(kPressTimeout * 2);
      expect(_backgroundOfLink(tester, _postWithLink, shown), isNotNull,
          reason: '$shown should be highlighted while pressed, like any link');

      await gesture.cancel();
      await tester.pump();
      expect(_backgroundOfLink(tester, _postWithLink, shown), isNull,
          reason: 'The highlight of $shown should go once the press ends');
    }
  });
  testWidgets('Should not leave a hashtag highlighted after a quick tap on it', (tester) async {
    final chains = Twitter.parseTweetDetail(fixture('TweetDetail', _postWithLink).body).chains;
    await pumpChains(tester, chains);

    await tester.tapAt(_centerOf(tester, _postWithLink, '#QuaXRunes'));
    await tester.pump();
    // The test app has no search page for the hashtag to open
    tester.takeException();

    expect(_backgroundOfLink(tester, _postWithLink, '#QuaXRunes'), isNull,
        reason: 'A tap too quick to show the highlight should not leave it on once the finger is lifted');
  });
}
