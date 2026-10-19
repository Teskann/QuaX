import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';

import '../fixtures.dart';
import '../tweet/pump_tweets.dart';
import '../ui/fake_images.dart';

int _counter = 0;

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should show every tweet of the home timeline', (tester) async {
    final chains = Twitter.createTimelineChains(fixture('HomeTimeline', 'vars-2a4d9c').body, 'tweet', const [], false,
            true, true, () => _counter, () => _counter++)
        .chains;
    await pumpChains(tester, chains);

    expect(tweetsOf(chains), isNotEmpty, reason: 'The home timeline should list tweets');
    expectEveryTweetRendered(chains);
  });
}
