import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:quax/client/client.dart';

import '../fixture_client.dart';
import '../fixtures.dart';

class _RecordingClient extends FixtureTwitterClient {
  _RecordingClient(super.fixtures);

  final requests = <Uri>[];

  @override
  Future<Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) {
    requests.add(uri);
    return super.get(uri, headers: headers, timeout: timeout);
  }
}

void main() {
  // The "Following" tab answers like the "For you" one, so the recorded home timeline stands in for it.
  final home = fixture('HomeTimeline', 'vars-2a4d9c');

  group('Twitter.getLatestHomeTimeline()', () {
    test('Should parse the chronological home timeline into posts', () async {
      Twitter.client = _RecordingClient({'HomeLatestTimeline': home});

      final status = await Twitter.getLatestHomeTimeline();

      expect(status.chains, isNotEmpty, reason: 'The recorded timeline holds posts');
      expect(status.chains.expand((c) => c.tweets).every((t) => t.user?.idStr != null && t.createdAt != null), isTrue,
          reason: 'Ranking needs the author and the date of every post');
    });

    test('Should ask X for the latest timeline with the page size and the cursor', () async {
      final client = _RecordingClient({'HomeLatestTimeline': home});
      Twitter.client = client;

      await Twitter.getLatestHomeTimeline(cursor: 'abc', count: 25);

      final uri = client.requests.single;
      final variables = jsonDecode(uri.queryParameters['variables']!) as Map<String, dynamic>;
      expect(uri.pathSegments.last, 'HomeLatestTimeline', reason: 'The chronological timeline is another operation');
      expect(variables['count'], 25, reason: 'The page size should be sent');
      expect(variables['cursor'], 'abc', reason: 'The cursor should fetch the next page');
      expect(variables['includePromotedContent'], false, reason: 'Ads are of no use to the ranking');
      expect(variables['latestControlAvailable'], true, reason: 'The web client sends it with this timeline');
      expect(uri.queryParameters['features'], isNotEmpty, reason: 'X rejects the request without the features');
    });

    test('Should leave the cursor out of the first page', () async {
      final client = _RecordingClient({'HomeLatestTimeline': home});
      Twitter.client = client;

      await Twitter.getLatestHomeTimeline();

      final variables = jsonDecode(client.requests.single.queryParameters['variables']!) as Map<String, dynamic>;
      expect(variables.containsKey('cursor'), isFalse, reason: 'A null cursor would be rejected by X');
      expect(variables['count'], 40, reason: 'A page should hold 40 posts by default');
    });
  });
}
