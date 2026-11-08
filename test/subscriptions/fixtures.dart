import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/subscriptions.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/back_interceptors.dart';

UserSubscription account(String name, {bool inFeed = true, DateTime? subscribedAt}) => UserSubscription(
  id: 'id-$name',
  screenName: name,
  name: name,
  profileImageUrlHttps: null,
  verified: false,
  createdAt: subscribedAt ?? DateTime(2026),
  inFeed: inFeed,
);

SearchSubscription savedSearch(String query) => SearchSubscription(id: query, createdAt: DateTime(2026));

CommunitySubscription followedCommunity(String name) =>
    CommunitySubscription(id: 'community-$name', name: name, bannerUrl: null, createdAt: DateTime(2026));

SubscriptionRef refOf(Subscription subscription) => SubscriptionRef.of(subscription);

Future<void> follow(List<Subscription> subscriptions) async {
  final database = await Repository.writable();
  for (final subscription in subscriptions) {
    await database.insert(SubscriptionKind.of(subscription).table, subscription.toMap());
  }
}

/// Returns the id of the new group.
Future<String> createGroup(String name, Iterable<Subscription> members, {Color? color}) async {
  await GroupsModel().saveGroup(
    GroupDraft(id: null, name: name, icon: defaultGroupIcon, color: color, members: members.map(refOf).toSet()),
    name,
  );
  final database = await Repository.readOnly();
  final rows = await database.query(tableSubscriptionGroup, where: 'name = ?', whereArgs: [name]);
  return rows.single['id'] as String;
}

Future<Set<SubscriptionRef>> membersOf(WidgetTester tester, String groupId) async => (await tester.runAsync(() async {
  final database = await Repository.readOnly();
  final rows = await database.query(tableSubscriptionGroupMember, where: 'group_id = ?', whereArgs: [groupId]);
  return refsOf(rows.map(SubscriptionGroupMember.fromMap)).toSet();
}))!;

/// The models of the app, loaded from what [follow] and [createGroup] stored, with the subscriptions page on screen.
/// They sit above the app, as in the real one, since the drag proxy and the editor route live there.
Widget Function(Widget) withSubscriptionModels() =>
    (app) => MultiProvider(
      providers: [
        Provider(create: (_) => GroupsModel()..reloadGroups()),
        Provider(lazy: false, create: (context) => GroupMembershipsModel(context.read<GroupsModel>())),
        Provider(
          lazy: false,
          create: (context) =>
              SubscriptionsModel(PrefService.of(context, listen: false), context.read<GroupsModel>())
                ..reloadSubscriptions(),
        ),
        Provider(create: (_) => BackInterceptors()..shownPage = subscriptionsPageId),
      ],
      child: app,
    );

/// Pumps until [condition] holds, letting the database answer meanwhile. Fails after [timeout].
Future<void> pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String reason,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out after $timeout: $reason');
    }
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 10)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> pumpUntilFound(WidgetTester tester, Finder finder) =>
    pumpUntil(tester, () => finder.evaluate().isNotEmpty, reason: 'nothing found by $finder');

Future<void> pumpUntilGone(WidgetTester tester, Finder finder) =>
    pumpUntil(tester, () => finder.evaluate().isEmpty, reason: 'still found by $finder');

void expectAbove(WidgetTester tester, String upper, String lower, {required String reason}) =>
    expect(tester.getTopLeft(find.text(upper)).dy, lessThan(tester.getTopLeft(find.text(lower)).dy), reason: reason);

/// A tall screen, so that the lazy lists build every row.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
