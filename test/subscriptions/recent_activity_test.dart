import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/subscriptions/recent_activity.dart';
import 'package:dart_twitter_api/twitter_api.dart' show User;

import 'import_fakes.dart';

void main() {
  final noon = DateTime(2024, 1, 1, 12);
  List<String> rank(List<String> ids, List<dynamic> chains) =>
      rankByRecentActivity(ids, (id) => id, chains.cast());

  group('rankByRecentActivity()', () {
    test('Should keep the order when the timeline is empty', () {
      expect(rank(['a', 'b', 'c'], []), ['a', 'b', 'c'], reason: 'With no activity known, X order is all we have');
    });

    test('Should return nothing when there is no follow', () {
      expect(rank([], [postBy('a', noon)]), isEmpty, reason: 'Accounts that are not followed should not appear');
    });

    test('Should put the seen accounts first, newest first, then the unseen in their order', () {
      final chains = [
        postBy('c', noon.subtract(const Duration(hours: 3))),
        postBy('e', noon),
      ];

      expect(rank(['a', 'b', 'c', 'd', 'e'], chains), ['e', 'c', 'a', 'b', 'd'],
          reason: 'Active accounts come first by recency, quiet ones keep their relative order after them');
    });

    test('Should use the newest of several posts of an account', () {
      final chains = [
        postBy('a', noon.subtract(const Duration(days: 2))),
        postBy('b', noon.subtract(const Duration(hours: 1))),
        postBy('a', noon),
        postBy('a', noon.subtract(const Duration(days: 5))),
      ];

      expect(rank(['b', 'a'], chains), ['a', 'b'], reason: 'Only the latest post of an account should count');
    });

    test('Should keep the original order of accounts posting at the same time', () {
      final chains = [postBy('c', noon), postBy('a', noon), postBy('b', noon)];

      expect(rank(['a', 'b', 'c'], chains), ['a', 'b', 'c'], reason: 'A tie should not reshuffle the accounts');
    });

    test('Should ignore authors that are not followed', () {
      final chains = [postBy('stranger', noon), postBy('b', noon.subtract(const Duration(hours: 1)))];

      expect(rank(['a', 'b'], chains), ['b', 'a'], reason: 'Unknown authors should not change the ranking');
    });

    test('Should ignore posts without an author or a date', () {
      final chains = [postBy(null, noon), postBy('a', null), postBy('b', noon)];

      expect(rank(['a', 'b'], chains), ['b', 'a'], reason: 'A post that can not be placed in time proves nothing');
    });

    test('Should count a repost for the account that reposted, not for the author', () {
      final original = TweetWithCard()
        ..user = (User()..idStr = 'b')
        ..createdAt = noon.subtract(const Duration(days: 3));
      final repost = TweetWithCard()
        ..user = (User()..idStr = 'a')
        ..createdAt = noon
        ..retweetedStatusWithCard = original;

      final ranked = rank(['b', 'c', 'a'], [TweetChain(id: '1', tweets: [repost], isPinned: false)]);

      expect(ranked, ['a', 'b', 'c'], reason: 'The reposter was active now, the author of the old post was not');
    });

    test('Should rank any kind of item through its id', () {
      final ranked = rankByRecentActivity(subscriptions(3), (s) => s.id, [postBy('3', noon)]);

      expect(ranked.map((s) => s.id), ['3', '1', '2'], reason: 'Subscriptions should be ranked by their id');
    });
  });
}
