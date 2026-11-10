import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';

import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'pump_tweets.dart';

const _postWithLink = '2095921351106146703';

/// The middle of [text] in the text of the post [id].
Offset _centerOf(WidgetTester tester, String id, String text) {
  final editable = _editableIn(
    tester.renderObject(find.descendant(of: tweetTile(id), matching: find.byType(EditableText)).first),
  )!;
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
}
