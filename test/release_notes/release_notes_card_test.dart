import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/release_notes/release_notes.dart';
import 'package:quax/release_notes/release_notes_card.dart';

import '../ui/pump_app.dart';

const _latest = ReleaseNote(version: '4.20.1', notes: [
  'Search results scroll smoothly again (fixed #311)',
  'Updated API calls (by @quax-bot)',
  'Refreshed the dependencies (by @github-actions[bot])',
]);

final _manyNotes = ReleaseNote(version: '4.20.0', notes: List.generate(12, (i) => 'Change $i'));

List<String> _spyOpenedLinks() {
  final urls = <String>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/url_launcher'), (call) async {
    urls.add((call.arguments as Map)['url'] as String);
    return true;
  });
  return urls;
}

Future<void> _pumpCard(WidgetTester tester, List<ReleaseNote> releases,
        {bool fullText = false, VoidCallback? onHide}) =>
    pumpInApp(tester, SingleChildScrollView(child: ReleaseNotesCard(releases: releases, onHide: onHide ?? () {})),
        prefs: {optionOpenLinksInEmbeddedBrowser: false, alwaysShowFullTweetContents: fullText});

List<TextSpan> _spans(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.textSpan)
    .whereType<TextSpan>()
    .expand((span) => span.children ?? const <InlineSpan>[])
    .whereType<TextSpan>()
    .toList();

void main() {
  testWidgets('Should open on GitHub the issues and the accounts the notes refer to', (tester) async {
    final opened = _spyOpenedLinks();
    await _pumpCard(tester, [_latest]);

    final links = _spans(tester).where((span) => span.recognizer != null).toList();
    for (final link in links) {
      (link.recognizer as TapGestureRecognizer).onTap!();
    }
    await tester.pump();

    expect(links.map((link) => link.text), ['#311', '@quax-bot', '@github-actions[bot]'],
        reason: 'The issue numbers and the GitHub accounts, whole, should be the only links');
    final accent = Theme.of(tester.element(find.byType(ReleaseNotesCard))).colorScheme.primary;
    expect(links.map((link) => link.style?.color), everyElement(accent),
        reason: 'The links should take the accent color of the app');
    expect(
        opened,
        [
          'https://github.com/teskann/quax/issues/311',
          'https://github.com/quax-bot',
          'https://github.com/apps/github-actions',
        ],
        reason: 'The links should lead to GitHub, where the issues and the accounts are, not to X');
  });

  testWidgets('Should title the notes of each version in bold, a little apart from them', (tester) async {
    await _pumpCard(tester, [_latest, _manyNotes]);

    final titles = tester
        .widgetList<Text>(find.textContaining('Version '))
        .where((text) => text.style?.fontWeight == FontWeight.bold)
        .map((text) => text.data);
    expect(titles, ['Version 4.20.1', 'Version 4.20.0'], reason: 'Each version should head its notes, newest first');
    final title = tester.getBottomLeft(find.text('Version 4.20.1')).dy;
    final notes = tester.getTopLeft(find.textContaining('Search results', findRichText: true)).dy;
    expect(notes - title, greaterThanOrEqualTo(8), reason: 'The notes should not stick to their version');
  });

  testWidgets('Should fold long notes behind Show more, like the posts', (tester) async {
    await _pumpCard(tester, [_manyNotes]);

    expect(find.textContaining('Change 4', findRichText: true), findsOneWidget, reason: 'The first notes are shown');
    expect(find.textContaining('Change 5', findRichText: true), findsNothing, reason: 'The others wait for Show more');

    await tester.tap(find.text('Show more'));
    await tester.pump();

    expect(find.textContaining('Change 11', findRichText: true), findsOneWidget,
        reason: 'Show more should reveal every note of the version');
    expect(find.text('Show more'), findsNothing, reason: 'Nothing is left to show');
  });

  testWidgets('Should indent the notes under their version', (tester) async {
    await _pumpCard(tester, [_latest]);

    final title = tester.getTopLeft(find.text('Version 4.20.1')).dx;
    final bullet = tester.getTopLeft(find.text('•   ').first).dx;
    final wrapped = tester.getTopLeft(find.textContaining('Search results', findRichText: true)).dx;
    expect(bullet, greaterThan(title), reason: 'The bullets should stand a little in from the version');
    expect(wrapped, greaterThan(bullet), reason: 'A long note should wrap under its own text, not under the bullet');
  });

  testWidgets('Should show all the notes when the posts are always shown whole', (tester) async {
    await _pumpCard(tester, [_manyNotes], fullText: true);

    expect(find.text('Show more'), findsNothing, reason: 'The option to show posts whole should apply to the notes');
  });

  testWidgets('Should hide the notes with their close button', (tester) async {
    var hidden = false;
    await _pumpCard(tester, [_latest], onHide: () => hidden = true);

    await tester.tap(find.byTooltip('Hide the release notes'));

    expect(hidden, isTrue, reason: 'The user dismissed the notes');
  });
}
