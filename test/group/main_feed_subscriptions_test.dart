import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/entities.dart';

void main() {
  UserSubscription user(String id, {bool inFeed = true}) => UserSubscription(
    id: id,
    screenName: id,
    name: id,
    profileImageUrlHttps: null,
    verified: false,
    createdAt: DateTime(2026),
    inFeed: inFeed,
  );

  SubscriptionGroupGet feed(String id, {required bool includeGroupMembers}) => SubscriptionGroupGet(
    id: id,
    name: id,
    icon: '',
    subscriptions: [user('grouped'), user('alone'), user('hidden', inFeed: false)],
    includeReplies: true,
    includeRetweets: true,
    includeGroupMembers: includeGroupMembers,
    groupMemberIds: {'grouped'},
  );

  List<String> ids(SubscriptionGroupGet group) => group.feedSubscriptions.map((s) => s.id).toList();

  test('Should leave out the accounts added to a group when the main feed excludes them', () {
    expect(ids(feed('-1', includeGroupMembers: false)), [
      'alone',
    ], reason: 'The accounts of a group are read in that group, so the main feed must not repeat their posts');
  });

  test('Should keep the accounts added to a group when the main feed includes them', () {
    expect(ids(feed('-1', includeGroupMembers: true)), [
      'grouped',
      'alone',
    ], reason: 'Including them is the default, and the main feed then shows every account in the feed');
  });

  test('Should keep the accounts of a group in that group whatever the main feed filter says', () {
    expect(ids(feed('group', includeGroupMembers: false)), [
      'grouped',
      'alone',
      'hidden',
    ], reason: 'The filter belongs to the main feed only, a group always shows all its members');
  });

  test('Should include the accounts added to a group by default', () {
    final group = SubscriptionGroupGet(
      id: '-1',
      name: '',
      icon: '',
      subscriptions: [],
      includeReplies: true,
      includeRetweets: true,
    );

    expect(
      group.includeGroupMembers,
      isTrue,
      reason: 'The main feed must not change for anyone who never touches the filter',
    );
  });
}
