import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/client.dart';
import 'package:quax/community/community.dart';
import 'package:quax/database/entities.dart';

import '../fixtures.dart';

Fixture _community() => fixture('CommunityQuery', 'vars-9a8157', unstable: true);

// Parsing changes the body it reads, so each test reads the file again
Fixture _posts() => fixture('CommunityTweetsTimeline', 'vars-a9e356', unstable: true);

Map<String, dynamic> _withResult(Map<String, dynamic> result) => {
      'data': {
        'communityResults': {'result': result}
      }
    };

void main() {
  group('Community.fromGraphql()', () {
    test('Should read what the header and the About tab show', () {
      final recorded = _community();
      final community = Community.fromGraphql(recorded.body);

      expect(community, isNotNull, reason: 'X answered a Community, so it should be read');
      expect(community!.id, recorded.sourceUrl.split('/').last,
          reason: 'The id should be the one of the community link that was opened');
      expect(community.name, isNotEmpty, reason: 'The header shows the community name');
      expect(community.description, isNotEmpty, reason: 'The About tab shows the description');
      expect(community.memberCount, greaterThan(0), reason: 'A public community has members');
      expect(community.bannerUrl, startsWith('https://'), reason: 'Every community has a custom or default banner');
      expect(community.createdAt, isNotNull, reason: 'The About tab shows when the community was created');
      expect(community.rules, isNotEmpty, reason: 'The recorded community has rules');
      expect(community.rules, everyElement(isNotEmpty), reason: 'Each rule should have its name');
      expect(community.memberAvatarUrls, everyElement(startsWith('https://')),
          reason: 'The header shows the avatars of a few members');
    });

    test('Should fall back to the default banner', () {
      final result = Map<String, dynamic>.of(_community().body['data']['communityResults']['result'])
        ..remove('custom_banner_media');

      expect(Community.fromGraphql(_withResult(result))?.bannerUrl,
          result['default_banner_media']['media_info']['original_img_url'],
          reason: 'A community without its own banner shows the default one, as on X');
    });

    test('Should read a community whose optional fields are missing', () {
      final community = Community.fromGraphql(_withResult({
        '__typename': 'Community',
        'rest_id': '1',
        'rules': {'unexpected': 'shape'},
        'members_facepile_results': [null, 'text'],
      }));

      expect(community?.id, '1', reason: 'The id is all the community screen needs to open');
      expect(community?.name, isEmpty, reason: 'A missing name should not throw');
      expect(community?.rules, isEmpty, reason: 'Rules that are not a list should be ignored');
      expect(community?.memberAvatarUrls, isEmpty, reason: 'Members that are not objects should be ignored');
      expect(community?.bannerUrl, isNull, reason: 'A missing banner should not throw');
    });

    test('Should give null when X sends no community', () {
      expect(Community.fromGraphql({'data': {'communityResults': {}}}), isNull,
          reason: 'A missing result should not throw, the screen shows an error card instead');
      expect(Community.fromGraphql(_withResult({'__typename': 'CommunityUnavailable'})), isNull,
          reason: 'An unavailable community has nothing to show');
    });
  });

  group('Twitter.parseCommunityTimeline()', () {
    test('Should read the posts of the community with their authors and the next page cursor', () {
      final status = Twitter.parseCommunityTimeline(_posts().body);

      expect(status.chains, isNotEmpty, reason: 'The Top tab of a busy community lists posts');
      expect(status.chains.expand((chain) => chain.tweets).map((tweet) => tweet.user?.screenName),
          everyElement(isNotNull), reason: 'Each post should have its author');
      expect(status.cursorBottom, isNotNull, reason: 'The next page loads from the bottom cursor');
    });

    test('Should give no posts when X sends no timeline', () {
      for (final result in [
        <String, dynamic>{},
        {'ranked_community_timeline': {}},
        {
          'ranked_community_timeline': {'timeline': {}}
        },
      ]) {
        final status = Twitter.parseCommunityTimeline(_withResult(result));

        expect(status.chains, isEmpty, reason: 'A missing timeline in $result should not throw');
        expect(status.cursorBottom, isNull, reason: 'Without a timeline there is no next page');
      }
    });
  });

  group('Twitter.parseCommunityMembers()', () {
    Fixture firstPage() => fixture('membersSliceTimeline_Query', 'vars-8805f9', unstable: true);

    test('Should read every member with what their tile shows, and the next page cursor', () {
      final recorded = firstPage();
      final found = recorded.body['data']['communityResults']['result']['members_slice']['items_results'] as List;
      final page = Twitter.parseCommunityMembers(recorded.body);

      expect(page.items, hasLength(found.length), reason: 'Each item of the slice is a member to list');
      expect(page.items.map((user) => user.screenName), everyElement(isNotEmpty),
          reason: 'Tapping a member opens their profile from the handle');
      expect(page.items.map((user) => user.name), everyElement(isNotNull), reason: 'Each tile shows the name');
      expect(page.items.map((user) => user.profileImageUrlHttps), everyElement(startsWith('https://')),
          reason: 'Each tile shows the avatar');
      expect(page.nextCursor, isNotNull, reason: 'The next members load from the cursor of the slice');
    });

    test('Should list members although X sends no account creation date for them', () {
      final members = Twitter.parseCommunityMembers(firstPage().body).items;

      expect(members.map((user) => user.createdAt), everyElement(isNull),
          reason: 'X sends no creation date in this list, which is what this test is about');
      expect(() => members.map(UserSubscription.fromUser).toList(), returnsNormally,
          reason: 'The members list shows each member in a UserTile, built from a UserSubscription');
    });

    test('Should skip members X sends without a handle or a name', () {
      final page = Twitter.parseCommunityMembers(_withResult({
        'members_slice': {
          'items_results': [
            null,
            {'result': null},
            {
              'result': {'rest_id': '1', 'core': {'name': 'No handle'}}
            },
            {
              'result': {'rest_id': '2', 'core': {'screen_name': 'no_name'}}
            },
            {
              'result': {'rest_id': '3', 'core': {'name': 'Kept', 'screen_name': 'kept'}}
            },
          ],
        },
      }));

      expect(page.items.map((user) => user.screenName), ['kept'],
          reason: 'A member without a handle cannot be opened, nor shown without a name');
      expect(page.nextCursor, isNull, reason: 'Without slice_info there is no next page');
    });

    test('Should give no members when X sends no slice', () {
      final page = Twitter.parseCommunityMembers(_withResult({}));

      expect(page.items, isEmpty, reason: 'A missing slice should not throw');
      expect(page.nextCursor, isNull, reason: 'Without a slice there is no next page');
    });
  });

  group('Twitter.parseCommunitiesSearch()', () {
    Fixture firstPage() => fixturesOf('CommunitiesSearchQuery').firstWhere((page) => page.variables['cursor'] == null);

    test('Should read every community found and the next page cursor', () {
      final recorded = firstPage();
      final found = recorded.body['data']['communities_search_slice']['items_results'] as List;
      final page = Twitter.parseCommunitiesSearch(recorded.body);

      expect(page.items, hasLength(found.length), reason: 'Each search result is a community to list');
      expect(page.items.map((community) => community.name), everyElement(isNotEmpty),
          reason: 'Each result shows the name of the community');
      expect(page.items.map((community) => community.memberCount), everyElement(greaterThan(0)),
          reason: 'Each result shows how many members the community has');
      expect(page.nextCursor, isNotNull, reason: 'The next results load from the cursor of the slice');
    });

    test('Should skip a result that is not a community', () {
      final page = Twitter.parseCommunitiesSearch({
        'data': {
          'communities_search_slice': {
            'items_results': [
              {'result': {'__typename': 'CommunityUnavailable'}},
              null,
              'text',
            ],
          },
        },
      });

      expect(page.items, isEmpty, reason: 'An unavailable community has nothing to open, so it should not be listed');
      expect(page.nextCursor, isNull, reason: 'Without slice_info there is no next page');
    });
  });
}
