// ignore: implementation_imports - convertTwitterDateTime is not exported by twitter_api.dart
import 'package:dart_twitter_api/src/utils/date_utils.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:extended_image/extended_image.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/add_to_groups_sheet.dart';
import 'package:quax/subscriptions/subscription_display.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:provider/provider.dart';

Widget _createUserAvatar(String? uri, double size) {
  if (uri == null) {
    return SizedBox(width: size, height: size);
  } else if (uri.startsWith('assets/')) {
    return Image.asset(uri, width: size, height: size);
  } else {
    return ExtendedImage.network(
      // TODO: This can error if the profile image has changed... use SWR-like
      uri.replaceAll('normal', '200x200'),
      width: size,
      height: size,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.failed:
            return const Icon(Icons.error_outline);
          default:
            return state.completedWidget;
        }
      },
    );
  }
}

/*
Widget _expandUserAvatar(String? uri, double size) {
  if (uri == null) {
    return SizedBox(width: size, height: size);
  } else {
    return ExtendedImage.network(
      // TODO: This can error if the profile image has changed... use SWR-like
      uri.replaceAll('normal', '400x400'),
      width: size,
      height: size,
      loadStateChanged: (state) {
        switch (state.extendedImageLoadState) {
          case LoadState.failed:
            return const Icon(Icons.error_outline);
          default:
            return state.completedWidget;
        }
      },
    );
  }
}
*/

class UserAvatar extends StatelessWidget {
  final String? uri;
  final double size;

  const UserAvatar({super.key, required this.uri, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size),
      child: _createUserAvatar(uri, size),
    );
  }
}

class UserTile extends StatelessWidget {
  final Subscription user;

  const UserTile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      leading: UserAvatar(uri: user.profileImageUrlHttps),
      title: Row(
        children: [
          Flexible(child: Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (user.verified) const SizedBox(width: 6),
          if (user.verified) Icon(Icons.verified, size: 14, color: Theme.of(context).colorScheme.primary)
        ],
      ),
      subtitle: Text('@${user.screenName}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: FollowButton(subscription: user),
      onTap: () {
        Navigator.pushNamed(context, routeProfile, arguments: ProfileScreenArguments(user.id, user.screenName, null));
      },
    );
  }
}

class FollowButton extends StatelessWidget {
  final Subscription subscription;
  final Color? color;

  const FollowButton({super.key, required this.subscription, this.color});

  @override
  Widget build(BuildContext context) {
    var model = context.read<SubscriptionsModel>();

    return ScopedBuilder<SubscriptionsModel, List<Subscription>>(
      store: model,
      onState: (_, state) {
        var ref = SubscriptionRef.of(subscription);
        var kind = ref.kind;
        var followed = state.where((element) => SubscriptionRef.of(element) == ref).firstOrNull;
        var inFeed = followed?.inFeed ?? false;
        var hidden = followed != null && kind.canHideFromMainFeed && !inFeed;

        var icon = followed == null
            ? Icon(kind.followIcon, color: color)
            : (hidden ? Icon(Icons.visibility_off) : Icon(kind.unfollowIcon, color: color));
        var text = followed != null ? L10n.of(context).unsubscribe : L10n.of(context).subscribe;

        return PopupMenuButton<String>(
          icon: icon,
          itemBuilder: (context) => [
            PopupMenuItem(value: 'toggle_subscribe', child: Text(text)),
            PopupMenuItem(
              value: 'add_to_group',
              child: Text(L10n.of(context).add_to_groups),
            ),
            if (followed != null && kind.canHideFromMainFeed)
              PopupMenuItem(
                value: 'toggle_in_main_feed',
                child: Text(inFeed ? L10n.of(context).hide_from_main_feed : L10n.of(context).show_in_main_feed),
              ),
          ],
          onSelected: (value) async {
            switch (value) {
              case 'add_to_group':
                if (followed == null) {
                  await model.subscribe(subscription);
                }
                if (context.mounted) {
                  await showGroupsSheet(context, [subscription], onDone: () {});
                }
              case 'toggle_subscribe':
                await (followed != null ? model.unsubscribe([followed]) : model.subscribe(subscription));
              case 'toggle_in_main_feed':
                await model.setShownInMainFeed([subscription], shown: !inFeed);
            }
          },
        );
      },
    );
  }
}

class UserWithExtra extends User {
  Map<String, dynamic>? card;
  bool? possiblySensitive;

  UserWithExtra();

  factory UserWithExtra.fromArguments({
    String? idStr,
    String? name,
    String? screenName,
    String? location,
    Derived? derived,
    String? url,
    UserEntities? entities,
    String? description,
    bool? protected,
    bool? verified,
    Tweet? status,
    int? followersCount,
    int? friendsCount,
    int? listedCount,
    int? favoritesCount,
    int? statusesCount,
    DateTime? createdAt,
    String? profileBannerUrl,
    String? profileImageUrlHttps,
    bool? defaultProfile,
    bool? defaultProfileImage,
    List<String>? withheldInCountries,
    String? withheldScope,
    bool? possiblySensitive,
  }) {
    var userWithExtra = UserWithExtra()
      ..idStr = idStr
      ..name = name
      ..screenName = screenName
      ..location = location
      ..derived = derived
      ..url = url
      ..entities = entities
      ..description = description
      ..protected = protected
      ..verified = verified
      ..status = status
      ..followersCount = followersCount
      ..friendsCount = friendsCount
      ..listedCount = listedCount
      ..favoritesCount = favoritesCount
      ..statusesCount = statusesCount
      ..createdAt = createdAt
      ..profileBannerUrl = profileBannerUrl
      ..profileImageUrlHttps = profileImageUrlHttps
      ..defaultProfile = defaultProfile
      ..defaultProfileImage = defaultProfileImage
      ..withheldInCountries = withheldInCountries
      ..withheldScope = withheldScope
      ..possiblySensitive = possiblySensitive;

    return userWithExtra;
  }

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['potentiallySensitive'] = possiblySensitive;

    return json;
  }

  factory UserWithExtra.fromNonLegacyJson(Map<String, dynamic> json) {
    var legacy = json['legacy'] as Map<String, dynamic>? ?? const {};
    return UserWithExtra.fromJson({...legacy, ..._flattenModernUser(json)});
  }

  static Map<String, dynamic> _flattenModernUser(Map<String, dynamic> json) {
    var avatar = _text(json['avatar']?['image_url']);
    var modern = <String, dynamic>{
      'id_str': json['rest_id'],
      'name': json['core']?['name'],
      'screen_name': json['core']?['screen_name'],
      'created_at': json['core']?['created_at'],
      'location': _text(json['location']?['location']),
      'url': _text(json['website']?['url']),
      'description': json['profile_bio']?['description'],
      'entities': json['profile_bio']?['entities'],
      'protected': json['privacy']?['protected'],
      'verified': json['verification']?['verified'],
      'verified_type': json['verification']?['verified_type'],
      'is_blue_verified': json['is_blue_verified'],
      'followers_count': json['relationship_counts']?['followers'],
      'friends_count': json['relationship_counts']?['following'],
      'favorites_count': json['action_counts']?['favorites_count'],
      'statuses_count': json['tweet_counts']?['tweets'],
      'profile_banner_url': _text(json['banner']?['image_url']),
      'profile_image_url_https': avatar,
      'possibly_sensitive': json['possibly_sensitive'],
      'default_profile_image': avatar?.contains('default_profile_images'),
    };
    modern.removeWhere((_, value) => value == null);
    return modern;
  }

  static String? _text(Object? value) {
    var text = value as String?;
    return (text == null || text.isEmpty) ? null : text;
  }

  static List<String> pinnedTweetIdsOf(Map<String, dynamic> json) {
    var ids = json['pinned_items']?['tweet_ids_str'] ?? json['legacy']?['pinned_tweet_ids_str'];
    return List<String>.from(ids as List<dynamic>? ?? const []);
  }

  static bool postsHiddenOf(Map<String, dynamic> json) {
    var protected = json['privacy']?['protected'] ?? json['legacy']?['protected'];
    var following = json['relationship_perspectives']?['following'] ?? json['legacy']?['following'];
    return protected == true && following != true;
  }

  factory UserWithExtra.fromJson(Map<String, dynamic> json) {
    var userWithExtra = UserWithExtra()
      ..idStr = json['id_str'] as String?
      ..name = json['name'] as String?
      ..screenName = json['screen_name'] as String?
      ..location = json['location'] as String?
      ..derived = json['derived'] == null ? null : Derived.fromJson(json['derived'] as Map<String, dynamic>)
      ..url = json['url'] as String?
      ..entities = json['entities'] == null ? null : UserEntities.fromJson(json['entities'] as Map<String, dynamic>)
      ..description = json['description'] as String?
      ..protected = json['protected'] as bool?
      ..verified = json['verified_type'] == "Business"
          ? true
          : json['ext_is_blue_verified'] ?? json['verified'] ?? json['is_blue_verified'] as bool?
      ..status = json['status'] == null ? null : Tweet.fromJson(json['status'] as Map<String, dynamic>)
      ..followersCount = json['followers_count'] as int?
      ..friendsCount = json['friends_count'] as int?
      ..listedCount = json['listed_count'] as int?
      ..favoritesCount = json['favorites_count'] as int?
      ..statusesCount = json['statuses_count'] as int?
      ..createdAt = convertTwitterDateTime(json['created_at'] as String?)
      ..profileBannerUrl = json['profile_banner_url'] as String?
      ..profileImageUrlHttps = json['profile_image_url_https'] as String?
      ..defaultProfile = json['default_profile'] as bool?
      ..defaultProfileImage = json['default_profile_image'] as bool?
      ..withheldInCountries = (json['withheld_in_countries'] as List<dynamic>?)?.map((e) => e as String).toList()
      ..withheldScope = json['withheld_scope'] as String?;

    userWithExtra.possiblySensitive = json['possibly_sensitive'] as bool?;

    return userWithExtra;
  }
}
