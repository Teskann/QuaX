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

    test('Should search a saved search as it was typed', () {
      expect(buildFeedSearchQuery([search('list:123 flutter')], includeReplies: true, includeRetweets: true),
          '((list:123 flutter)) include:nativeretweets',
          reason: 'Quoted, the saved search was looked up as literal text, so its operators were ignored and '
              'the group showed old or no posts while the same search opened alone showed the latest');
    });

    test('Should keep the words of a saved search together when mixed with other subscriptions', () {
      expect(buildFeedSearchQuery([user('a'), search('flutter dart')], includeReplies: true, includeRetweets: true),
          '(from:a OR (flutter dart)) include:nativeretweets',
          reason: 'X binds an implicit AND tighter than OR, so without its brackets the saved search would '
              'become from:a OR flutter, then AND dart, and the posts of from:a without dart would be lost');
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
    test('Should trip its own guard when one subscription fills the whole query', () {
      expect(() => buildFeedSearchQuery([search('x' * 600)], includeReplies: true, includeRetweets: true),
          throwsA(isA<AssertionError>()),
          reason: 'The builder assumes a chunk fits in the ~512 character query, which holds for the 16 '
              'accounts a chunk carries but not for a very long search subscription. The guard says so in '
              'debug rather than silently dropping the subscriptions read before it');
    });
  });
}
