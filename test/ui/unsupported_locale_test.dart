import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';

import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import 'fake_images.dart';

int _counter = 0;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should show the home timeline in Esperanto', (tester) async {
    final chains = Twitter.createTimelineChains(fixture('HomeTimeline', 'vars-2a4d9c', unstable: true).body, 'tweet',
            const [], false, true, true, () => _counter, () => _counter++)
        .chains;
    await pumpChains(tester, chains, locale: const Locale('eo'));

    expect(tester.takeException(), isNull,
        reason: 'Flutter and intl have no Esperanto data, so the app should fall back to English for them');
    expectEveryTweetRendered(chains);
    expect(L10n.current.language, 'Lingvo', reason: 'Only what Flutter and intl lack should fall back to English');
  });
}
