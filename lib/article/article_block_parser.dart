import 'package:flutter/material.dart';

import 'package:quax/article/article_text_block.dart';

ArticleTextBlock blockToRichText(Map<String, dynamic> block, {TextStyle? baseStyle}) {
  final String text = (block['text'] ?? '') as String;
  final String type = (block['type'] ?? 'unstyled') as String;
  final List<dynamic> inlineStyleRanges = (block['inlineStyleRanges'] ?? []) as List<dynamic>;
  final List<dynamic> entityRanges = (block['entityRanges'] ?? []) as List<dynamic>;
  final Map<String, dynamic>? data = block['data'] as Map<String, dynamic>?;
  final List<dynamic> dataUrls = (data?['urls'] ?? []) as List<dynamic>;
  final List<dynamic> dataMentions = (data?['mentions'] ?? []) as List<dynamic>;

  final TextStyle defaultStyle = baseStyle ?? const TextStyle();
  final TextStyle blockStyle = _styleForBlockType(type, defaultStyle);

  final List<TextSpan> children = _buildStyledTextSpans(text, inlineStyleRanges, entityRanges, dataUrls, dataMentions, blockStyle);

  switch (type) {
    case 'atomic':
      return ArticleTextBlock(TextSpan(), entityRanges, ArticleTextBlockType.atomic);
    case 'unordered-list-item':
      return ArticleTextBlock(
        TextSpan(style: blockStyle, children: children),
        entityRanges,
        ArticleTextBlockType.unorderedListItem,
      );
    case 'ordered-list-item':
      return ArticleTextBlock(
        TextSpan(style: blockStyle, children: children),
        entityRanges,
        ArticleTextBlockType.orderedListItem,
      );
    case 'header-two':
      return ArticleTextBlock(TextSpan(style: blockStyle, children: children), entityRanges, ArticleTextBlockType.headerTwo);
    case 'blockquote':
      return ArticleTextBlock(TextSpan(style: blockStyle, children: children), entityRanges, ArticleTextBlockType.blockquote);
    case 'unstyled':
    default:
      return ArticleTextBlock(TextSpan(style: blockStyle, children: children), entityRanges, ArticleTextBlockType.unstyled);

  }
}

TextStyle _styleForBlockType(String type, TextStyle baseStyle) {
  switch (type) {
    case 'header-two':
      return baseStyle.copyWith(fontSize: 22, fontWeight: FontWeight.w700, height: 1.4);
    case 'unordered-list-item':
    case 'ordered-list-item':
      return baseStyle.copyWith(fontSize: 14, height: 1.5);
    case 'unstyled':
    default:
      return baseStyle.copyWith(fontSize: 14, height: 1.5);
  }
}

List<TextSpan> _buildStyledTextSpans(String text, List<dynamic> inlineStyleRanges, List<dynamic> entityRanges, List<dynamic> dataUrls, List<dynamic> dataMentions, TextStyle baseStyle) {
  if (text.isEmpty) return [TextSpan(text: '', style: baseStyle)];

  final markers = _parseStyleMarkers(text, inlineStyleRanges);
  final entityMarkers = _parseEntityMarkers(text, entityRanges);
  final urlMarkers = _parseUrlMarkers(text, dataUrls);
  final mentionMarkers = _parseMentionMarkers(text, dataMentions);

  if (markers.isEmpty && entityMarkers.isEmpty && urlMarkers.isEmpty && mentionMarkers.isEmpty) return [TextSpan(text: text, style: baseStyle)];

  final List<TextSpan> spans = [];
  int current = 0;

  while (current < text.length) {
    final activeStyles = markers.where((m) => current >= m.start && current < m.end).toList();
    final activeEntities = entityMarkers.where((m) => current >= m.start && current < m.end).toList();
    final activeUrls = urlMarkers.where((m) => current >= m.start && current < m.end).toList();
    final activeMentions = mentionMarkers.where((m) => current >= m.start && current < m.end).toList();
    final nextBreak = _findNextBreak(current, text.length, markers, entityMarkers, urlMarkers, mentionMarkers);

    final String segment = text.substring(current, nextBreak);
    TextStyle segmentStyle = baseStyle;
    for (final marker in activeStyles) {
      segmentStyle = _applyInlineStyle(segmentStyle, marker.style);
    }

    spans.add(_buildSegmentSpan(segment, segmentStyle, activeEntities, activeUrls, activeMentions));
    current = nextBreak;
  }

  return spans;
}

// Converts a Unicode code point offset to a Dart UTF-16 code unit offset.
// Necessary because the API provides code point offsets, but Dart's String
// is UTF-16 where emojis (and other non-BMP characters) occupy 2 code units.
int _cpToUtf16(String text, int cpOffset) {
  int utf16 = 0;
  int cp = 0;
  for (final rune in text.runes) {
    if (cp == cpOffset) break;
    utf16 += rune > 0xFFFF ? 2 : 1;
    cp++;
  }
  return utf16;
}

List<_StyleMarker> _parseStyleMarkers(String text, List<dynamic> inlineStyleRanges) {
  final markers = <_StyleMarker>[];
  for (final dynamic range in inlineStyleRanges) {
    if (range is! Map<String, dynamic>) continue;
    final int cpStart = (range['offset'] ?? 0) as int;
    final int cpLength = (range['length'] ?? 0) as int;
    final String styleName = (range['style'] ?? '') as String;
    final int start = _cpToUtf16(text, cpStart);
    final int end = _cpToUtf16(text, cpStart + cpLength);
    if (start < 0 || end > text.length || start >= end) continue;
    markers.add(_StyleMarker(start: start, end: end, style: styleName));
  }
  return markers;
}

List<_EntityMarker> _parseEntityMarkers(String text, List<dynamic> entityRanges) {
  final entityMarkers = <_EntityMarker>[];
  for (final dynamic range in entityRanges) {
    if (range is! Map<String, dynamic>) continue;
    final int cpStart = (range['offset'] ?? 0) as int;
    final int cpLength = (range['length'] ?? 0) as int;
    final dynamic key = range['key'];
    final int start = _cpToUtf16(text, cpStart);
    final int end = _cpToUtf16(text, cpStart + cpLength);
    if (start < 0 || end > text.length || start >= end) continue;
    entityMarkers.add(_EntityMarker(start: start, end: end, key: key));
  }
  return entityMarkers;
}

List<_UrlMarker> _parseUrlMarkers(String text, List<dynamic> dataUrls) {
  final urlMarkers = <_UrlMarker>[];
  for (final dynamic entry in dataUrls) {
    if (entry is! Map<String, dynamic>) continue;
    final int cpStart = (entry['fromIndex'] ?? 0) as int;
    final int cpEnd = (entry['toIndex'] ?? 0) as int;
    final String urlText = (entry['text'] ?? '') as String;
    final int start = _cpToUtf16(text, cpStart);
    final int end = _cpToUtf16(text, cpEnd);
    if (start < 0 || end > text.length || start >= end) continue;
    urlMarkers.add(_UrlMarker(start: start, end: end, url: urlText));
  }
  return urlMarkers;
}

int _findNextBreak(int current, int textLength, List<_StyleMarker> markers, List<_EntityMarker> entityMarkers, [List<_UrlMarker> urlMarkers = const [], List<_MentionMarker> mentionMarkers = const []]) {
  int nextBreak = textLength;
  for (final marker in markers) {
    if (marker.start > current && marker.start < nextBreak) nextBreak = marker.start;
    if (marker.end > current && marker.end < nextBreak) nextBreak = marker.end;
  }
  for (final marker in entityMarkers) {
    if (marker.start > current && marker.start < nextBreak) nextBreak = marker.start;
    if (marker.end > current && marker.end < nextBreak) nextBreak = marker.end;
  }
  for (final marker in urlMarkers) {
    if (marker.start > current && marker.start < nextBreak) nextBreak = marker.start;
    if (marker.end > current && marker.end < nextBreak) nextBreak = marker.end;
  }
  for (final marker in mentionMarkers) {
    if (marker.start > current && marker.start < nextBreak) nextBreak = marker.start;
    if (marker.end > current && marker.end < nextBreak) nextBreak = marker.end;
  }
  return nextBreak;
}

TextSpan _buildSegmentSpan(String segment, TextStyle style, List<_EntityMarker> activeEntities, [List<_UrlMarker> activeUrls = const [], List<_MentionMarker> activeMentions = const []]) {
  if (activeEntities.isNotEmpty) {
    return EntityPlaceHolderTextSpan(
      entityText: segment,
      entityKey: activeEntities.first.key,
      style: style,
    );
  }
  if (activeUrls.isNotEmpty) {
    return DataUrlTextSpan(
      text: segment,
      url: activeUrls.first.url,
      style: style,
    );
  }
  if (activeMentions.isNotEmpty) {
    return DataMentionTextSpan(
      text: segment,
      screenName: activeMentions.first.screenName,
      style: style,
    );
  }
  return TextSpan(text: segment, style: style);
}

TextStyle _applyInlineStyle(TextStyle style, String styleName) {
  switch (styleName.toLowerCase()) {
    case 'bold':
      return style.copyWith(fontWeight: FontWeight.bold);
    case 'italic':
      return style.copyWith(fontStyle: FontStyle.italic);
    case 'underline':
      return style.copyWith(decoration: TextDecoration.underline);
    default:
      return style;
  }
}

class _StyleMarker {
  final int start;
  final int end;
  final String style;

  _StyleMarker({required this.start, required this.end, required this.style});
}

class _EntityMarker {
  final int start;
  final int end;
  final dynamic key;

  _EntityMarker({required this.start, required this.end, required this.key});
}

class _UrlMarker {
  final int start;
  final int end;
  final String url;

  _UrlMarker({required this.start, required this.end, required this.url});
}

List<_MentionMarker> _parseMentionMarkers(String text, List<dynamic> dataMentions) {
  final mentionMarkers = <_MentionMarker>[];
  for (final dynamic entry in dataMentions) {
    if (entry is! Map<String, dynamic>) continue;
    final int cpStart = (entry['fromIndex'] ?? 0) as int;
    final int cpEnd = (entry['toIndex'] ?? 0) as int;
    final String screenName = (entry['text'] ?? '') as String;
    final int start = _cpToUtf16(text, cpStart);
    final int end = _cpToUtf16(text, cpEnd);
    if (start < 0 || end > text.length || start >= end) continue;
    mentionMarkers.add(_MentionMarker(start: start, end: end, screenName: screenName));
  }
  return mentionMarkers;
}

class _MentionMarker {
  final int start;
  final int end;
  final String screenName;

  _MentionMarker({required this.start, required this.end, required this.screenName});
}
