import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/group/search_query.dart';

void main() {
  UserSubscription user(String screenName) => UserSubscription(
      id: screenName,
      screenName: screenName,
      name: screenName,
      profileImageUrlHttps: null,
      verified: false,
      createdAt: DateTime(2026),
      inFeed: true);

  SearchSubscription search(String term) => SearchSubscription(id: term, createdAt: DateTime(2026));

  group('buildFeedSearchQuery() subscriptions', () {
    test('Should put the subscriptions in brackets so the filters apply to all of them', () {
      expect(buildFeedSearchQuery([user('a'), user('b')], includeReplies: false, includeRetweets: true),
          '(from:a OR from:b) -filter:replies include:nativeretweets',
          reason: 'X binds an implicit AND tighter than OR, so without the brackets the filter would only '
              'apply to from:b, and replies from every other account of the group would still come back');
    });

    test('Should keep the brackets around a single subscription', () {
      expect(buildFeedSearchQuery([user('a')], includeReplies: false, includeRetweets: true),
          '(from:a) -filter:replies include:nativeretweets',
          reason: 'A group of one is the same query with nothing to group, and brackets that are always '
              'there are one shape to read rather than two');
    });

    test('Should join the subscriptions with OR', () {
      expect(buildFeedSearchQuery([user('a'), user('b'), user('c')], includeReplies: true, includeRetweets: true),
          '(from:a OR from:b OR from:c) include:nativeretweets',
          reason: 'A group feed is every subscription at once, so a post matching any one of them belongs '
              'in it. An AND would ask for a post written by all three at the same time');
    });

    test('Should quote a search subscription so its words are looked up together', () {
      expect(buildFeedSearchQuery([search('flutter forever')], includeReplies: true, includeRetweets: true),
          '("flutter forever") include:nativeretweets',
          reason: 'Without the quotes X would look for the words apart, so a subscription to a phrase '
              'would bring back posts that only share one word of it');
    });

    test('Should mix user and search subscriptions in the same query', () {
      expect(buildFeedSearchQuery([user('a'), search('dart')], includeReplies: true, includeRetweets: true),
          '(from:a OR "dart") include:nativeretweets',
          reason: 'A group can hold both kinds at once, and both are looked up by the one request that '
              'loads the chunk');
    });

    test('Should leave out the brackets when the group has no subscription', () {
      expect(buildFeedSearchQuery([], includeReplies: true, includeRetweets: true), 'include:nativeretweets',
          reason: 'Empty brackets are not a query X can read, so a group with nothing in it should not '
              'break the request');
    });
  });

  group('buildFeedSearchQuery() replies', () {
    test('Should ask X to leave out replies when the group hides them', () {
      expect(buildFeedSearchQuery([user('a')], includeReplies: false, includeRetweets: true),
          contains('-filter:replies'),
          reason: 'Letting X drop the replies keeps the pages full. Dropping them here once the answer '
              'has come back shortens every page and can empty one entirely');
    });

    test('Should not name the replies filter when the group shows them', () {
      expect(buildFeedSearchQuery([user('a')], includeReplies: true, includeRetweets: true),
          isNot(contains('filter:replies')),
          reason: 'Replies belong in the feed unless the group says otherwise, so nothing about them '
              'should be asked for');
    });
  });

  group('buildFeedSearchQuery() retweets', () {
    test('Should ask X to leave out retweets when the group hides them', () {
      expect(buildFeedSearchQuery([user('a')], includeReplies: true, includeRetweets: false),
          '(from:a) -filter:retweets',
          reason: 'The retweet setting works the same way as the reply one, and should sit next to the '
              'reply filter rather than replace it');
    });

    test('Should ask X for native retweets when the group shows them', () {
      expect(buildFeedSearchQuery([user('a')], includeReplies: true, includeRetweets: true),
          '(from:a) include:nativeretweets',
          reason: 'X leaves retweets out of a search unless they are asked for, so showing them needs a '
              'keyword of its own rather than the absence of a filter');
    });

    test('Should keep both filters when the group hides replies and retweets', () {
      expect(buildFeedSearchQuery([user('a'), user('b')], includeReplies: false, includeRetweets: false),
          '(from:a OR from:b) -filter:replies -filter:retweets',
          reason: 'The two settings are independent, so turning both off should give both filters, after '
              'the bracketed subscriptions so they cover all of them');
    });

    test('Should never ask for retweets with filter:retweets', () {
      expect(buildFeedSearchQuery([user('a')], includeReplies: true, includeRetweets: true),
          isNot(contains('filter:retweets')),
          reason: 'filter: narrows a search down to what it names, so filter:retweets would leave the '
              'feed with retweets and quotes and no posts of its own. include: is the one that adds');
    });

    test('Should not ask for native retweets when the group hides retweets', () {
      expect(buildFeedSearchQuery([user('a')], includeReplies: true, includeRetweets: false),
          isNot(contains('nativeretweets')),
          reason: 'The two keywords pull against each other, so asking X to add native retweets in the '
              'same breath as hiding retweets would leave what comes back up to X');
    });
  });

  group('buildFeedSearchQuery() replies and retweets together', () {
    test('Should give a query for each of the four settings a group can have', () {
      final queries = [
        for (var replies in [true, false])
          for (var retweets in [true, false])
            buildFeedSearchQuery([user('a')], includeReplies: replies, includeRetweets: retweets)
      ];

      expect(queries, [
        '(from:a) include:nativeretweets',
        '(from:a) -filter:retweets',
        '(from:a) -filter:replies include:nativeretweets',
        '(from:a) -filter:replies -filter:retweets'
      ], reason: 'The two switches of the group settings screen are read on their own, so each of the '
          'four ways they can be set should give the query that matches it');
    });
  });

  group('buildFeedSearchQuery() length limit', () {
    test('Should trip its own guard when a packed chunk builds a query X would reject', () {
      final overflowing = List.generate(20, (i) => user('handle${i.toString().padLeft(9, '0')}'));

      expect(() => buildFeedSearchQuery(overflowing, includeReplies: false, includeRetweets: true),
          throwsA(isA<AssertionError>()),
          reason: 'Twenty of the longest handles join to 476 characters, under the limit, but build a 517 '
              'character query once the brackets and filters are added, so the guard has to measure the '
              'finished query rather than the terms alone');
    });

    test('Should stay silent for a single subscription too long to ever fit', () {
      expect(() => buildFeedSearchQuery([search('x' * 600)], includeReplies: true, includeRetweets: true),
          returnsNormally,
          reason: 'No packing can make one oversized subscription fit, so it is left to fail against X as a '
              'retryable error rather than crashing the app in debug');
    });
  });

  group('packFeedChunks()', () {
    List<List<Subscription>> pack(List<Subscription> subscriptions) =>
        packFeedChunks(subscriptions, includeReplies: false, includeRetweets: true);

    test('Should never build a query longer than the limit', () {
      final chunks = pack(List.generate(50, (i) => user('h${i.toString().padLeft(14, '0')}')));

      expect(
          chunks.map((chunk) =>
              buildFeedSearchQuery(chunk, includeReplies: false, includeRetweets: true).length <= maxQueryLength),
          everyElement(isTrue),
          reason: 'The packer exists to keep every chunk under the length X accepts, so no chunk it produces '
              'may build a query over it');
    });

    test('Should pack the mix of handles and search phrases that a fixed chunk size overflows', () {
      final subscriptions = [
        ...List.generate(8, (i) => user('handle$i')),
        ...List.generate(8, (i) => search('a' * 40)),
      ];

      expect(pack(subscriptions).length, greaterThan(1),
          reason: 'Search phrases have no length bound, so sixteen of these subscriptions overflow one query '
              'even though the old fixed chunk size of 16 sent them as one for X to reject');
    });

    test('Should give a subscription too long to fit a chunk of its own', () {
      final chunks = pack([user('a'), search('x' * 600), user('b')]);

      expect(chunks.map((chunk) => chunk.length), [1, 1, 1],
          reason: 'An unpackable subscription is isolated so it fails on its own request, leaving the '
              'subscriptions around it to load normally');
    });

    test('Should keep the order it is given', () {
      final subscriptions = List.generate(40, (i) => user('h${i.toString().padLeft(14, '0')}'));

      expect(pack(subscriptions).expand((chunk) => chunk), subscriptions,
          reason: 'Chunks are packed oldest first so adding a subscription only disturbs the last chunk and '
              'the cached preview of the others stays warm');
    });

    test('Should produce no chunks for no subscriptions', () {
      expect(pack([]), isEmpty, reason: 'An empty group has nothing to search for, so it should ask X nothing');
    });
  });
}
