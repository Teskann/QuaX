import 'package:dart_twitter_api/twitter_api.dart';
import 'package:html_unescape/html_unescape.dart';
import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import 'package:quax/constants.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/search/search.dart';
import 'package:quax/ui/link_style.dart';
import 'package:quax/utils/urls.dart';
import 'package:quax/utils/iterables.dart';
import 'package:quax/utils/_entities.dart';

// RichText (not sure if it has an official name) is the way urls, mentions, hashtags... are integrated on
// twitter content (tweets and descriptions).
// It uses Entities (objects with fields such as display_url, url (t.co) and indices)

class RichTextPart {
  final InlineSpan? entity;
  String? plainText;

  RichTextPart(this.entity, this.plainText);

  @override
  String toString() {
    return plainText ?? '';
  }
}

List<InlineSpan> displayRichText(List<RichTextPart> richText) {
  return richText.map((e) {
    if (e.plainText != null) {
      return TextSpan(text: e.plainText);
    } else {
      return e.entity!;
    }
  }).toList();
}

// Generate all the tweet entities (mentions, hashtags, etc.) from the tweet text
// [cardUrl], the link a card was made from, is dropped when the card shows what it leads to, such as a Grok
// conversation or a space
List<RichTextPart> buildRichText(BuildContext context, String rawText, Object? rawEntities, {String? cardUrl}) {
  Runes runes = Runes(rawText);
  Iterable<int> runesAsIterable = runes.getRange(0, runes.length);

  List<Entity> entities = [];
  if (rawEntities != null) {
    entities = _parseEntities(context, rawEntities, cardUrl: cardUrl);
  }
  List<RichTextPart> richTextParts = [];

  int index = 0;
  for (var part in entities) {
    int start = part.getEntityStart();
    int end = part.getEntityEnd();

    // Add any text between the last entity's end and the start of this one
    _handleTextParts(context, _convertRunesToText(runesAsIterable, index, start), richTextParts);

    // Then add the actual entity
    richTextParts.add(RichTextPart(part.getContent(linkStyle(context)), null));

    // Then set our index in the tweet text as the end of our entity
    index = end;
  }
  // And end by adding any text between the last entity and the end of the text
  var textPart = _convertRunesToText(runesAsIterable, index);
  _handleTextParts(context, textPart, richTextParts);

  return _trimEnd(_trimStart(_closeGaps(richTextParts)));
}

bool _isDropped(RichTextPart part) => part.plainText == null && (part.entity?.toPlainText() ?? '').isEmpty;

// Once a link is dropped, the texts around it meet: they keep the wider of their two gaps, not both
List<RichTextPart> _closeGaps(List<RichTextPart> parts) =>
    parts.where((part) => !_isDropped(part)).fold(<RichTextPart>[], (kept, part) {
      final before = kept.lastOrNull?.plainText;
      final after = part.plainText;
      if (before == null || after == null) return [...kept, part];
      return [...kept.take(kept.length - 1), RichTextPart(null, _joinOverGap(before, after))];
    });

String _joinOverGap(String before, String after) {
  final gapBefore = before.substring(before.trimRight().length);
  final gapAfter = after.substring(0, after.length - after.trimLeft().length);
  return before.trimRight() + (gapBefore.length >= gapAfter.length ? gapBefore : gapAfter) + after.trimLeft();
}

bool _isBlank(RichTextPart part) => (part.plainText ?? part.entity?.toPlainText() ?? '').trim().isEmpty;

// The text shown starts and ends with what is visible, whatever was dropped around it
List<RichTextPart> _trimStart(List<RichTextPart> parts) {
  final first = parts.indexWhere((part) => !_isBlank(part));
  if (first == -1) return [];
  final text = parts[first].plainText;
  return [text == null ? parts[first] : RichTextPart(null, text.trimLeft()), ...parts.skip(first + 1)];
}

List<RichTextPart> _trimEnd(List<RichTextPart> parts) {
  final last = parts.lastIndexWhere((part) => !_isBlank(part));
  if (last == -1) return [];
  final text = parts[last].plainText;
  return [...parts.take(last), text == null ? parts[last] : RichTextPart(null, text.trimRight())];
}

// In descriptions, the hashtags and mentions are not seen as entities, so we parse them manually
void _handleTextParts(BuildContext context, String? text, List<RichTextPart> richTextParts) {
  if (text == null) return;
  List parsedText = _parseMentionsAndHashtags(context, text);
  for (var t in parsedText) {
    if (t is String) {
      richTextParts.add(RichTextPart(null, t));
    }
    if (t is InlineSpan) {
      richTextParts.add(RichTextPart(t, null));
    }
  }
}

List _parseMentionsAndHashtags(BuildContext context, String content) {
  List contentWidgets = [];

  // Split the string by any mentions or hashtags, and turn those into links
  content.splitMapJoin(RegExp(r'(#|(?<=\W|^)@)\w+'), onMatch: (match) {
    var full = match.group(0);
    var type = match.group(1);
    if (type == null || full == null) {
      return '';
    }

    var onTap = () async {};
    if (type == '#') {
      onTap = () async {
        Navigator.pushNamed(context, routeSearch,
            arguments:
                SearchArguments(SearchTab.latest, focusInputOnOpen: false, query: full));
      };
    }
    if (type == '@') {
      onTap = () async {
        Navigator.pushNamed(context, routeProfile,
            arguments:
                ProfileScreenArguments.fromScreenName(full.substring(1), null));
      };
    }
    contentWidgets.add(TextSpan(
        text: full,
        style: linkStyle(context),
        recognizer: TapGestureRecognizer()..onTap = onTap));
    return type;
  }, onNonMatch: (text) {
    contentWidgets.add(text);
    return text;
  });

  return contentWidgets;
}

String? _convertRunesToText(Iterable<int> runes, int start, [int? end]) {
  var string =
      runes.getRange(start, end).map((e) => String.fromCharCode(e)).join('');
  if (string.isEmpty) {
    return null;
  }
  return HtmlUnescape().convert(string);
}

final _shownByItsCard = RegExp(r'^https?://(x|twitter)\.com/i/(grok/share|spaces)/');

List<Entity> _parseEntities(BuildContext context, dynamic newEntities, {String? cardUrl}) {
  List<Entity> entities = [];
  if (newEntities == null) return entities;

  if (newEntities is Map<String, dynamic>){
    // try using newEntities as a raw json object (that's what we get from the translation API)
    newEntities = Entities.fromJson(newEntities);
  }

  if (newEntities is! Entities && newEntities is! UserEntityUrl){
      return entities;
  }

  // in tweets all entities types can be present (Entities object)
  // but in profile description there can be only urls (UserEntityUrl object)
  if (newEntities is Entities) {
    for (Media media in newEntities.media ?? []) {
      entities.add(MediaEntity(media));
    }

    for (Hashtag hashtag in newEntities.hashtags ?? []) {
      entities.add(HashtagEntity(
          hashtag,
          () => Navigator.pushNamed(context, routeSearch,
              arguments: SearchArguments(SearchTab.latest,
                  focusInputOnOpen: false, query: '#${hashtag.text}'))));
    }

    for (UserMention mention in newEntities.userMentions ?? []) {
      entities.add(UserMentionEntity(
          mention,
          () => Navigator.pushNamed(context, routeProfile,
              arguments:
                  ProfileScreenArguments(mention.idStr, mention.screenName, null))));
    }
  }

  for (Url url in newEntities.urls ?? []) {
    if (url.url == cardUrl && _shownByItsCard.hasMatch(url.expandedUrl ?? '')) {
      entities.add(HiddenUrlEntity(url));
      continue;
    }
    entities.add(UrlEntity(url, () async {
      String? uri = url.expandedUrl;
      if (uri == null ||
          (uri.length > 33 &&
              uri.substring(0, 33) == 'https://twitter.com/i/web/status/') ||
          (uri.length > 27 &&
              uri.substring(0, 27) == 'https://x.com/i/web/status/')) {
        return;
      }
      await openUri(context, uri);
    }));
  }

  entities.sort((a, b) => a.getEntityStart().compareTo(b.getEntityStart()));

  return entities;
}
