import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

abstract class Entity {
  List<int>? indices;
  
  Entity(this.indices);
  
  InlineSpan getContent(TextStyle linkStyle);
  
  int getEntityStart() {
    return indices![0];
  }
  
  int getEntityEnd() {
    return indices![1];
  }
}

class HashtagEntity extends Entity {
  final Hashtag hashtag;
  final Function onTap;

  HashtagEntity(this.hashtag, this.onTap) : super(hashtag.indices);

  @override
  InlineSpan getContent(TextStyle linkStyle) {
    return TextSpan(
        text: '#${hashtag.text}',
        style: linkStyle,
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
  InlineSpan getContent(TextStyle linkStyle) {
    return TextSpan(
        text: '@${mention.screenName}',
        style: linkStyle,
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
  InlineSpan getContent(TextStyle linkStyle) {
    return TextSpan(
        text: url.displayUrl,
        style: linkStyle,
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            onTap();
          });
  }
}

class HiddenUrlEntity extends Entity {
  HiddenUrlEntity(Url url) : super(url.indices);

  @override
  InlineSpan getContent(TextStyle linkStyle) {
    return const TextSpan(text: "");
  }
}

class MediaEntity extends Entity {
  final Media media;

  MediaEntity(this.media) : super(media.indices);

  @override
  InlineSpan getContent(TextStyle linkStyle) {
    return TextSpan(text: "");
  }
}