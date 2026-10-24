import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';

import '../../tool/mock_x/fixture_map.dart';
import '../mock_x_client.dart';

RecordedRequest _recorded(Map<String, dynamic> variables, {Map<String, dynamic>? features}) =>
    RecordedRequest('test/fixtures/TweetDetail/1.json', {
      'host': 'x.com',
      'queryId': 'abc',
      'operation': 'TweetDetail',
      'variables': variables,
      'features': features ?? {'a': true},
      'fieldToggles': null,
      'status': 200,
      'body': {'data': 'recorded'},
    });

Uri _sent(Map<String, dynamic> variables, {Map<String, dynamic>? features, String queryId = 'abc'}) =>
    Uri.https('x.com', '/i/api/graphql/$queryId/TweetDetail', {
      'variables': jsonEncode(variables),
      'features': jsonEncode(features ?? {'a': true}),
    });

int _counter = 0;

/// QuaX's request for the page [recorded] holds, from its cursor, or null when the app never sends it.
Future<void> Function(String? cursor)? _appPages(RecordedRequest recorded) {
  final variables = recorded.parameters['variables'] as Map<String, dynamic>? ?? const {};
  final userId = variables['userId'] as String?;
  Future<void> timeline(String type, String? cursor, {bool includeReplies = false}) => Twitter.getTweets(
      userId!, type, const [],
      count: 20, cursor: cursor, includeReplies: includeReplies,
      getTweetsCounter: () => _counter, incrementTweetsCounter: () => _counter++);

  return switch (recorded.operation) {
    'UserByScreenName' => (_) => Twitter.getProfileByScreenName(variables['screen_name']),
    'TweetDetail' => (cursor) => Twitter.getTweet(variables['focalTweetId'], cursor: cursor),
    'Following' => (cursor) => Twitter.friendsList(userId!, 20, cursor: cursor),
    'Followers' => (cursor) => Twitter.followersList(userId!, 20, cursor: cursor),
    'SearchTimeline' when variables['product'] == 'People' =>
      (cursor) => Twitter.searchUsers(variables['rawQuery'], cursor: cursor),
    'SearchTimeline' => (cursor) =>
        Twitter.searchTweets(variables['rawQuery'], product: variables['product'], cursor: cursor),
    'HomeTimeline' => (cursor) => Twitter.getTimelineTweets('home',
        cursor: cursor, getTweetsCounter: () => _counter, incrementTweetsCounter: () => _counter++),
    // The Popular sort of the website, which QuaX does not offer
    'UserOriginalsTimeline' when variables['sortByMostLiked'] == true => null,
    'UserOriginalsTimeline' => (cursor) => timeline('profile', cursor),
    'UserTweetsAndReplies' => (cursor) => timeline('profile', cursor, includeReplies: true),
    'CommunityQuery' => (_) => Twitter.getCommunity(variables['communityId']),
    'CommunityTweetsTimeline' => (cursor) => Twitter.getCommunityTweets(variables['communityId'], cursor: cursor),
    'CommunitiesSearchQuery' => (cursor) => Twitter.searchCommunities(variables['query'], cursor: cursor),
    'membersSliceTimeline_Query' => (cursor) => Twitter.getCommunityMembers(variables['communityId'], cursor: cursor),
    'UserVideoTimeline' => (cursor) => timeline('media', cursor),
    'UserPhotoTimeline' => (cursor) => timeline('photos', cursor),
    _ => null,
  };
}

void main() {
  group('Mock of X', () {
    test('Should answer a request that is exactly a recorded one', () {
      final answer = FixtureMap([_recorded({'focalTweetId': '1'})]).answer(_sent({'focalTweetId': '1'}));

      expect(answer.status, 200, reason: 'An exact match should get the recorded status');
      expect(jsonDecode(answer.body), {'data': 'recorded'}, reason: 'An exact match should get the recorded body');
    });

    test('Should name a feature the app does not send', () {
      final answer = FixtureMap([
        _recorded({'focalTweetId': '1'}, features: {'a': true, 'b': false})
      ]).answer(_sent({'focalTweetId': '1'}));

      expect(answer.matched, isFalse, reason: 'A missing feature should not be answered, even if X would accept it');
      expect(answer.body, contains('features.b: missing'), reason: 'The answer should name the missing feature');
    });

    test('Should name a variable the website never sent', () {
      final answer = FixtureMap([_recorded({'focalTweetId': '1'})]).answer(_sent({'focalTweetId': '1', 'count': 10}));

      expect(answer.body, contains('variables.count: sent 10, never recorded'),
          reason: 'The answer should name the extra variable and its value');
    });

    test('Should answer a request without the tweets the website reports as seen', () {
      final answer = FixtureMap([
        _recorded({'cursor': 'c', 'seenTweetIds': ['1']})
      ]).answer(_sent({'cursor': 'c'}));

      expect(answer.matched, isTrue, reason: 'QuaX never tells X what was read, so seenTweetIds must not matter');
    });

    test('Should name a stale queryId', () {
      final answer = FixtureMap([_recorded({'focalTweetId': '1'})]).answer(_sent({'focalTweetId': '1'}, queryId: 'old'));

      expect(answer.body, contains('queryId: sent old, recorded abc'), reason: 'The answer should show both queryIds');
    });

    test('Should explain that non-GraphQL requests are never recorded', () {
      final answer = FixtureMap([]).answer(Uri.https('api.x.com', '/1.1/trends/available.json'));

      expect(answer.status, 501, reason: 'An unrecorded request should fail');
      expect(answer.body, contains('only X GraphQL requests'), reason: 'The answer should say why nothing can match');
    });
  });

  group('App requests match the fixtures', () {
    final fixtures = FixtureMap.load(Directory('test/fixtures'));
    final client = MockXClient(fixtures);

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await L10n.load(const Locale('en'));
      Twitter.client = client;
    });

    test('Should ask for a profile the way the website does, whatever the case of the link', () async {
      client.answers.clear();
      await Twitter.getProfileByScreenName('Quax_Tests');

      expect(client.answers.single.matched, isTrue,
          reason: 'The website sends handles in lower case, a link may not. ${client.answers.single.body}');
    });

    for (final recorded in fixtures.requests) {
      final pages = _appPages(recorded);
      if (pages == null) continue;

      test('Should send exactly the request of ${recorded.file}', () async {
        client.answers.clear();
        try {
          await pages((recorded.parameters['variables'] as Map?)?['cursor'] as String?);
        } on Object {
          // Parsing is fixtures_test's job: here only the request matters
        }

        final answer = client.answers.single;
        expect(answer.matched, isTrue, reason: answer.body);
      });
    }
  });
}
