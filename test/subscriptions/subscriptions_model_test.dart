import 'package:flutter_test/flutter_test.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/subscriptions/users_model.dart';

import '../group/open_feed.dart';
import 'fixtures.dart';

PrefServiceCache _prefs({String legacyCustomOrder = ''}) =>
    PrefServiceCache(defaults: {...subscriptionPrefDefaults, optionSubscriptionOrderCustom: legacyCustomOrder});

final _search = savedSearch('flutter');

void main() {
  useFreshDatabase();

  test('Should keep the custom order set in an older version', () async {
    final prefs = _prefs(legacyCustomOrder: 'flutter,FlutterDev');
    final subscriptions = SubscriptionsModel(prefs, GroupsModel());
    await follow([flutterDev, _search]);

    await subscriptions.reloadSubscriptions();
    expect(subscriptions.state.map((s) => s.id), [
      _search.id,
      flutterDev.id,
    ], reason: 'The order chosen in an older version should show at once, as when a backup is restored');

    await subscriptions.reloadSubscriptions();
    expect(subscriptions.state.map((s) => s.id), [
      _search.id,
      flutterDev.id,
    ], reason: 'The order should still show after a reload');
  });
}
