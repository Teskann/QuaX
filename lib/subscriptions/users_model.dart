import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/utils/iterables.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';

class SubscriptionsModel extends Store<List<Subscription>> {
  static final log = Logger('SubscriptionsModel');

  final BasePrefService prefs;
  final GroupsModel groupModel;

  SubscriptionsModel(this.prefs, this.groupModel) : super([]);

  Future<void> reloadSubscriptions() async {
    log.info('Listing subscriptions');

    await execute(() async {
      var database = await Repository.readOnly();

      String orderCustom = prefs.get(optionSubscriptionOrderCustom);
      bool orderByAscending = prefs.get(optionSubscriptionOrderByAscending);
      String orderByField = prefs.get(optionSubscriptionOrderByField);

      List<Subscription> users = (await database.query(tableSubscription)).map((e) => UserSubscription.fromMap(e)).toList();

      List<Subscription> searches = (await database.query(tableSearchSubscription)).map((e) => SearchSubscription.fromMap(e)).toList();

      List<Subscription> lst = [...users, ...searches];
      if (orderCustom.isEmpty) {
        return lst.sorted((a, b) {
          var one = orderByAscending ? a : b;
          var two = orderByAscending ? b : a;

          switch (orderByField) {
            case 'name':
              return one.name.toLowerCase().compareTo(two.name.toLowerCase());
            case 'screen_name':
              return one.screenName.toLowerCase().compareTo(two.screenName.toLowerCase());
            case 'created_at':
              return one.createdAt.compareTo(two.createdAt);
            default:
              return one.name.toLowerCase().compareTo(two.name.toLowerCase());
          }
        }).toList();
      }
      else {
        List<Subscription> newLst = [];
        for(String screenName in orderCustom.split(',')) {
          Subscription? s = lst.firstWhereOrNull((e) => e.screenName == screenName);
          if (s != null) {
            lst.removeWhere((e) => e.screenName == screenName);
            newLst.add(s);
          }
        }
        if (lst.isNotEmpty) {
          newLst.addAll(lst);
        }
        await prefs.set(optionSubscriptionOrderCustom, newLst.map((s) => s.screenName).join(','));
        return newLst;
      }
    });
  }

  Future<void> refreshSubscriptionData() async {
    log.info('Refreshing subscription data');

    await execute(() async {
      var database = await Repository.writable();

      var ids = (await database.query(tableSubscription, columns: ['id'])).map((e) => e['id'] as String).toList();

      var users = await Twitter.getUsers(ids);

      var batch = database.batch();
      for (var user in users) {
        batch.update(
            tableSubscription,
            {
              'screen_name': user.screenName,
              'name': user.name,
              'profile_image_url_https': user.profileImageUrlHttps,
              'verified': (user.verified ?? false) ? 1 : 0
            },
            where: 'id = ?',
            whereArgs: [user.idStr]);
      }

      await batch.commit();
      await reloadSubscriptions();

      return state;
    });
  }

  Future<void> _toggleSearchSubscribe(SearchSubscription user, bool currentlyFollowed) async {
    var database = await Repository.writable();

    await execute(() async {
      if (currentlyFollowed) {
        await database.delete(tableSearchSubscription, where: 'id = ?', whereArgs: [user.id]);
        await database.delete(tableSearchSubscriptionGroupMember, where: 'search_id = ?', whereArgs: [user.id]);

        state.removeWhere((e) => e.id == user.id);
      } else {
        database.insert(tableSearchSubscription, {
          'id': user.id,
        });
      }

      // TODO: This is hardcore, but we need to resort the list and this is the easiest way
      await reloadSubscriptions();

      return state;
    });
  }

  Future<void> _toggleUserSubscribe(UserSubscription user, bool currentlyFollowed) async {
    var database = await Repository.writable();

    await execute(() async {
      if (currentlyFollowed) {
        await database.delete(tableSubscription, where: 'id = ?', whereArgs: [user.id]);
        await database.delete(tableSubscriptionGroupMember, where: 'profile_id = ?', whereArgs: [user.id]);

        state.removeWhere((e) => e.id == user.id);
      } else {
        database.insert(tableSubscription, {
          'id': user.id,
          'screen_name': user.screenName,
          'name': user.name,
          'profile_image_url_https': user.profileImageUrlHttps,
          'verified': user.verified ? 1 : 0
        });
      }

      // TODO: This is hardcore, but we need to resort the list and this is the easiest way
      await reloadSubscriptions();

      return state;
    });

    await groupModel.reloadGroups();
  }

  Future<void> toggleSubscribe(Subscription user, bool currentlyFollowed) async {
    if (user is UserSubscription) {
      await _toggleUserSubscribe(user, currentlyFollowed);
    } else if (user is SearchSubscription) {
      await _toggleSearchSubscribe(user, currentlyFollowed);
    }

    await groupModel.reloadGroups();
  }

  Future<void> changeOrderSubscriptionsBy(String? value) async {
    await execute(() async {
      await prefs.set(optionSubscriptionOrderCustom, '');
      await prefs.set(optionSubscriptionOrderByField, value ?? 'name');
      await reloadSubscriptions();

      return state;
    });
  }

  Future<void> toggleOrderSubscriptionsAscending() async {
    await execute(() async {
      await prefs.set(optionSubscriptionOrderCustom, '');
      await prefs.set(optionSubscriptionOrderByAscending, !prefs.get(optionSubscriptionOrderByAscending));
      await reloadSubscriptions();

      return state;
    });
  }
}
