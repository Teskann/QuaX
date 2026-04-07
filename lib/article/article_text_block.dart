import 'package:flutter/material.dart';

enum ArticleTextBlockType {
  unorderedListItem,
  orderedListItem,
  headerTwo,
  unstyled,
  atomic,
  blockquote
}

class ArticleTextBlock {
  InlineSpan inlineSpan;
  List<dynamic> entityRanges;
  ArticleTextBlockType type;

  ArticleTextBlock(this.inlineSpan, this.entityRanges, this.type);
}

class EntityPlaceHolderTextSpan extends TextSpan {
  final String entityText;
  final int entityKey;

  const EntityPlaceHolderTextSpan({
    required this.entityText,
    required this.entityKey,
    super.style,
  }) : super(text: entityText);
}

class DataUrlTextSpan extends TextSpan {
  final String url;

  const DataUrlTextSpan({
    required String text,
    required this.url,
    super.style,
  }) : super(text: text);
}

class DataMentionTextSpan extends TextSpan {
  final String screenName;

  const DataMentionTextSpan({
    required String text,
    required this.screenName,
    super.style,
  }) : super(text: text);
}
