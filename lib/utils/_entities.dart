import 'package:dart_twitter_api/twitter_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/utils/link_gesture_recognizer.dart';
import 'package:quax/utils/pressed_link_model.dart';

/// The span of a link showing [text], highlighted by [pressedLink] while pressed.
TextSpan linkSpan(String text, Function onTap, PressedLinkModel? pressedLink, {VoidCallback? onLongPress}) =>
    TextSpan(
        text: text,
        recognizer: LinkGestureRecognizer(pressedLink: pressedLink)
          ..onTap = () {
            onTap();
          }
          ..onLongPress = onLongPress);

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
}

class HashtagEntity extends Entity {
  final Hashtag hashtag;
  final Function onTap;
  final PressedLinkModel? pressedLink;

  HashtagEntity(this.hashtag, this.onTap, {this.pressedLink}) : super(hashtag.indices);

  @override
  InlineSpan getContent() => linkSpan('#${hashtag.text}', onTap, pressedLink);
}

class UserMentionEntity extends Entity {
  final UserMention mention;
  final Function onTap;
  final PressedLinkModel? pressedLink;

  UserMentionEntity(this.mention, this.onTap, {this.pressedLink}) : super(mention.indices);

  @override
  InlineSpan getContent() => linkSpan('@${mention.screenName}', onTap, pressedLink);
}

class UrlEntity extends Entity {
  final Url url;
  final Function onTap;
  final VoidCallback? onLongPress;
  final PressedLinkModel? pressedLink;

  UrlEntity(this.url, this.onTap, this.onLongPress, {this.pressedLink}) : super(url.indices);

  @override
  InlineSpan getContent() => linkSpan(url.displayUrl ?? '', onTap, pressedLink, onLongPress: onLongPress);
}

class HiddenUrlEntity extends Entity {
  HiddenUrlEntity(Url url) : super(url.indices);

  @override
  InlineSpan getContent() {
    return const TextSpan(text: "");
  }
}

class MediaEntity extends Entity {
  final Media media;

  MediaEntity(this.media) : super(media.indices);

  @override
  InlineSpan getContent() {
    return TextSpan(text: "");
  }
}