import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/lists/x_list.dart';

import '../fixtures.dart';
import 'pump_list.dart';

List<Map<String, dynamic>> _instructions(Fixture page, String timeline) =>
    (page.body['data']['list'][timeline]['timeline']['instructions'] as List).cast<Map<String, dynamic>>();

bool _endsAtBottom(Fixture page, String timeline) => _instructions(
  page,
  timeline,
).any((instruction) => instruction['type'] == 'TimelineTerminateTimeline' && instruction['direction'] == 'Bottom');

/// The ids of the posts X sends in the threads of [page].
List<String> _threadPostIds(Fixture page) => _instructions(page, 'tweets_timeline')
    .expand((instruction) => (instruction['entries'] as List? ?? const []).cast<Map<String, dynamic>>())
    .where((entry) => (entry['entryId'] as String).startsWith('list-conversation-'))
    .expand((entry) => (entry['content']['items'] as List).cast<Map<String, dynamic>>())
    .map((item) => item['item']['itemContent']['tweet_results']['result']['rest_id'] as String)
    .toList();

/// The ids of the reposts that X wraps in a TweetWithVisibilityResults in [page].
List<String> _wrappedRepostIds(Fixture page) => _instructions(page, 'tweets_timeline')
    .expand((instruction) => (instruction['entries'] as List? ?? const []).cast<Map<String, dynamic>>())
    .map((entry) => entry['content']?['itemContent']?['tweet_results']?['result'])
    .where((result) => result?['__typename'] == 'TweetWithVisibilityResults')
    .map((result) => result['tweet'])
    .where((tweet) => tweet?['legacy']?['retweeted_status_result']?['result'] != null)
    .map((tweet) => tweet['rest_id'] as String)
    .toList();

Fixture _firstPage(Iterable<Fixture> pages) => pages.firstWhere((page) => page.variables['cursor'] == null);

void main() {
  group('XList.fromGraphql()', () {
    test('Should read what the header of a list shows', () {
      final list = XList.fromGraphql(recordedListPage().body);

      expect(list?.id, recordedListId, reason: 'The id should be the one of the list link that was opened');
      expect(list!.name, isNotEmpty, reason: 'The header shows the name of the list');
      expect(list.bannerUrl, startsWith('https://'), reason: 'Every list has a custom or default banner');
      expect(list.memberCount, greaterThan(0), reason: 'The header shows how many accounts the list holds');
      expect(list.followerCount, greaterThan(0), reason: 'The header shows how many accounts follow the list');
      expect(list.owner?.screenName, isNotEmpty, reason: 'The header shows who made the list, and opens their profile');
      expect(list.followerAvatarUrls, isNotEmpty, reason: 'The header shows the photos of a few followers');
      expect(
        list.followerAvatarUrls,
        everyElement(contains('_normal.')),
        reason: 'X sends tiny photos. The normal ones stay sharp on the screen',
      );
    });

    test('Should read a list whose optional fields are missing', () {
      final list = XList.fromGraphql({
        'data': {
          'list': {
            'id_str': '1',
            'description': '',
            'user_results': {'result': 'text'},
          },
        },
      });

      expect(list?.id, '1', reason: 'The id is all the list screen needs to open');
      expect(list?.name, isEmpty, reason: 'A missing name should not throw');
      expect(list?.description, isNull, reason: 'An empty description is no description');
      expect(list?.owner, isNull, reason: 'An owner that is not an object should be ignored');
      expect(list?.bannerUrl, isNull, reason: 'A missing banner should not throw');
    });

    test('Should give null when X sends no list', () {
      expect(
        XList.fromGraphql({'data': {}}),
        isNull,
        reason: 'A missing list should not throw. The screen shows an error card instead',
      );
    });
  });

  group('Twitter.parseListTweets()', () {
    test('Should read the posts of the list with their authors and the next page cursor', () {
      final status = Twitter.parseListTweets(_firstPage(listPages('ListLatestTweetsTimeline')).body);

      expect(status.chains, isNotEmpty, reason: 'A busy list shows the posts of its members');
      expect(
        status.chains.expand((chain) => chain.tweets).map((tweet) => tweet.user?.screenName),
        everyElement(isNotNull),
        reason: 'Each post should have its author',
      );
      expect(status.cursorBottom, isNotNull, reason: 'The next page loads from the bottom cursor');
    });

    test('Should show the threads of the members, with the posts around them', () {
      final pages = listPages('ListLatestTweetsTimeline').toList();
      final threads = pages.expand(_threadPostIds).toList();
      final shown = pages
          .expand((page) => Twitter.parseListTweets(page.body).chains)
          .expand((chain) => chain.tweets)
          .map((tweet) => tweet.idStr);

      expect(threads, isNotEmpty, reason: 'The capture should hold threads for this test to mean much');
      expect(
        shown,
        containsAll(threads),
        reason: 'X sends threads apart from the other posts. The website shows them, so QuaX should too',
      );
    });

    test('Should read a repost as a repost when X wraps it with its reply limits', () {
      final page = _firstPage(listPages('ListLatestTweetsTimeline'));
      final wrapped = _wrappedRepostIds(page);
      final reposts = Twitter.parseListTweets(page.body).chains
          .expand((chain) => chain.tweets)
          .where((tweet) => tweet.retweetedStatus != null)
          .map((tweet) => tweet.idStr);

      expect(wrapped, isNotEmpty, reason: 'The capture should hold such reposts for this test to mean much');
      expect(
        reposts,
        containsAll(wrapped),
        reason: 'A wrapped repost should show the reposted post',
      );
    });

    test('Should give no posts when X sends no timeline', () {
      final status = Twitter.parseListTweets({
        'data': {'list': {}},
      });

      expect(status.chains, isEmpty, reason: 'A missing timeline should not throw');
      expect(status.cursorBottom, isNull, reason: 'Without a timeline there is no next page');
    });
  });

  group('Twitter.parseListMembers()', () {
    test('Should read the members of a page with what their tile shows, and the next page cursor', () {
      final page = Twitter.parseListMembers(_firstPage(listPages('ListMembers')).body);

      expect(page.items, isNotEmpty, reason: 'The recorded list has members');
      expect(
        page.items.map((user) => user.screenName),
        everyElement(isNotEmpty),
        reason: 'Tapping a member opens their profile from the handle',
      );
      expect(
        page.items.map((user) => user.profileImageUrlHttps),
        everyElement(startsWith('https://')),
        reason: 'Each tile shows the photo',
      );
      expect(page.nextCursor, isNotNull, reason: 'The next members load from the bottom cursor');
    });

    test('Should read the followers of a list like its members', () {
      final page = Twitter.parseListFollowers(_firstPage(listPages('ListSubscribers')).body);

      expect(
        page.items.map((user) => user.screenName),
        allOf(isNotEmpty, everyElement(isNotEmpty)),
        reason: 'Each follower is shown and opened like a member',
      );
      expect(page.nextCursor, isNotNull, reason: 'The next followers load from the bottom cursor');
    });

    test('Should end the members at the page where X ends the timeline', () {
      final last = listPages('ListMembers').singleWhere((page) => _endsAtBottom(page, 'members_timeline'));
      final entries = _instructions(last, 'members_timeline').expand((i) => i['entries'] as List? ?? const []);

      expect(
        entries.where((entry) => entry['content']?['cursorType'] == 'Bottom'),
        isNotEmpty,
        reason: 'X sends a cursor even with its last page, which is what this test is about',
      );
      expect(
        Twitter.parseListMembers(last.body).nextCursor,
        isNull,
        reason: 'The website does not follow that cursor, so QuaX should not either',
      );
    });
  });

  group('Twitter.parseListsSearch()', () {
    test('Should read the lists of the first page and of the next ones', () {
      final pages = listSearchPages().toList();
      final first = Twitter.parseListsSearch(_firstPage(pages).body).items;
      final next = pages.where((page) => page.variables['cursor'] != null).expand((page) {
        return Twitter.parseListsSearch(page.body).items;
      }).toList();

      expect(first, isNotEmpty, reason: 'The first page puts its lists in a module');
      expect(next, isNotEmpty, reason: 'The next pages add their lists to that module');
      expect(
        [...first, ...next].map((list) => list.name),
        everyElement(isNotEmpty),
        reason: 'Each result shows the name of the list',
      );
      expect(
        [...first, ...next].map((list) => list.owner?.screenName),
        everyElement(isNotNull),
        reason: 'Each result shows who made the list',
      );
    });
  });
}
