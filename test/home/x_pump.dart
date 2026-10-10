import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/home/x_account_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/locale_fallback.dart';
import 'package:quax/user.dart';

SubscriptionGroup fakeGroup(String id, String name) => SubscriptionGroup(
    id: id, name: name, icon: defaultGroupIcon, color: null, numberOfMembers: 0, createdAt: DateTime(2024));

Account fakeAccount(String screenName) => Account(id: 'a-$screenName', authHeader: '{}', screenName: screenName);

UserWithExtra fakeUser({String name = 'Jane Doe', int? following = 69, int? followers = 8, String? image}) =>
    UserWithExtra()
      ..name = name
      ..friendsCount = following
      ..followersCount = followers
      ..profileImageUrlHttps = image;

/// An account model whose network is faked: [accounts] are the stored accounts and [user] answers every lookup.
XAccountModel fakeAccountModel({List<Account> accounts = const [], UserWithExtra? user}) =>
    XAccountModel(accounts: () async => accounts, profile: (_) async => user ?? fakeUser());

class XTestApp {
  final GroupsModel groups;
  final BasePrefService prefs;
  final List<String> pushed;

  XTestApp(this.groups, this.prefs, this.pushed);
}

/// Pumps [home] in an app with what the X design reads: the account model and the groups. Named routes are
/// recorded in [XTestApp.pushed] and show their name.
Future<XTestApp> pumpXApp(
  WidgetTester tester,
  Widget home, {
  XAccountModel? account,
  List<SubscriptionGroup> groups = const [],
  Map<String, dynamic> prefs = const {},
  Brightness brightness = Brightness.light,
}) async {
  final service = PrefServiceCache(defaults: {
    optionXStyle: true,
    optionThemeMode: 'system',
    optionHomeDefaultFeedTab: 'following',
    optionTweetsHideSensitive: true,
    optionMediaDefaultMute: true,
    ...prefs,
  });
  final groupsModel = GroupsModel(service)..update(groups);
  final pushed = <String>[];
  await tester.pumpWidget(PrefService(
    service: service,
    child: MultiProvider(
      providers: [
        Provider<XAccountModel>.value(value: account ?? fakeAccountModel()),
        Provider<GroupsModel>.value(value: groupsModel),
        Provider<SubscriptionsModel>.value(value: SubscriptionsModel(service, groupsModel)),
      ],
      child: MaterialApp(
        theme: ThemeData(brightness: brightness),
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: L10n.delegate.supportedLocales,
        onGenerateRoute: (settings) {
          pushed.add(settings.name!);
          return MaterialPageRoute(settings: settings, builder: (_) => Scaffold(body: Text('route ${settings.name}')));
        },
        home: home,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return XTestApp(groupsModel, service, pushed);
}
