import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:quax/constants.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/search/search.dart';
import 'package:quax/utils/urls.dart';


abstract class Entity {
  List<int>? indices;

  Entity(this.indices);

  InlineSpan getContent();

  int getEntityStart() {
    return indices![0];
  }

  int getEntityEnd() {
    return indices![1];
  }

  static List<Entity> parseEntities(BuildContext context, dynamic newEntities) {
    List<Entity> entities = [];

    // in tweets all entities types can be present (Entities object)
    // but in profile description there can be only urls (UserEntityUrl object)
    if (newEntities is Entities) {
      for (Hashtag hashtag in newEntities.hashtags ?? []) {
        entities.add(HashtagEntity(
            hashtag, () =>
            Navigator.pushNamed(
                context, routeSearch, arguments: SearchArguments(1, focusInputOnOpen: false, query: '#${hashtag.text}')
            )
        ));
      }

      for (UserMention mention in newEntities.userMentions ?? []) {
        entities.add(UserMentionEntity(
            mention, () =>
            Navigator.pushNamed(
                context, routeSearch, arguments: ProfileScreenArguments(mention.idStr, mention.screenName)
            )
        ));
      }
    }

    for (Url url in newEntities.urls ?? []) {
      entities.add(UrlEntity(url, () async {
        String? uri = url.expandedUrl;
        if (uri == null ||
            (uri.length > 33 && uri.substring(0, 33) == 'https://twitter.com/i/web/status/') ||
            (uri.length > 27 && uri.substring(0, 27) == 'https://x.com/i/web/status/')) {
          return;
        }
        await openUri(uri);
      }));
    }

    entities.sort((a, b) => a.getEntityStart().compareTo(b.getEntityStart()));

    return entities;
  }
}

class HashtagEntity extends Entity {
  final Hashtag hashtag;
  final Function onTap;

  HashtagEntity(this.hashtag, this.onTap) : super(hashtag.indices);

  @override
  InlineSpan getContent() {
    return TextSpan(
        text: '#${hashtag.text}',
        style: const TextStyle(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}

class UserMentionEntity extends Entity {
  final UserMention mention;
  final Function onTap;

  UserMentionEntity(this.mention, this.onTap) : super(mention.indices);

  @override
  InlineSpan getContent() {
    return TextSpan(
        text: '@${mention.screenName}',
        style: const TextStyle(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}

class UrlEntity extends Entity {
  final Url url;
  final Function onTap;

  UrlEntity(this.url, this.onTap) : super(url.indices);

  @override
  InlineSpan getContent() {
    return TextSpan(
        text: url.displayUrl,
        style: const TextStyle(color: Colors.blue),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}
