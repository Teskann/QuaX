import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:quax/article/article_parser.dart';
import 'package:quax/constants.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/utils/urls.dart';

class Article {
  final String title;
  final String previewText;
  final List<ArticleTextBlock> textParts;
  Map<int, EntityValue> entities;
  ImageEntity? coverMedia;

  Article(this.title, this.previewText, this.textParts, this.entities, this.coverMedia);

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'previewText': previewText,
      'coverMediaUrl': coverMedia?.imageUrl,
    };
  }

  factory Article.fromJson(Map<String, dynamic> e) {
    final coverMediaUrl = e['coverMediaUrl'] as String?;
    return Article(
      e['title'] as String? ?? '',
      e['previewText'] as String? ?? '',
      [],
      {},
      coverMediaUrl == null ? null : ImageEntity(imageUrl: coverMediaUrl),
    );
  }

  factory Article.fromGraphqlJson(Map<String, dynamic> articleResult, String tweetIdStr, String user) {
    final title = articleResult["title"] ?? "";
    final previewText = articleResult["preview_text"] ?? "";

    Map<int, EntityValue> entities = {};
    if (articleResult["content_state"]?["entityMap"] != null && articleResult["media_entities"] != null) {
      entities = EntityMapParser.parse(
        articleResult["content_state"]["entityMap"] is List<dynamic> ? articleResult["content_state"]["entityMap"] : [],
        articleResult["media_entities"],
        tweetIdStr,
        user,
      );
    }

    final blocks = articleResult["content_state"]?["blocks"] ?? [];
    final coverMediaJson = articleResult["cover_media"]?["media_info"]?["original_img_url"];

    final coverMedia = coverMediaJson == null ? null : ImageEntity(imageUrl: coverMediaJson);
    return Article(title, previewText, List.from(blocks.map((e) => blockToRichText(e))), entities, coverMedia);
  }
}

class ArticleWidget extends StatelessWidget {
  final Article article;
  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;
  final TextStyle? previewStyle;
  final TextStyle? contentStyle;
  final bool expand;
  final VoidCallback? onTap;
  final Widget? bottomBar;

  const ArticleWidget({
    super.key,
    required this.article,
    this.padding = const EdgeInsets.all(16),
    this.titleStyle,
    this.previewStyle,
    this.contentStyle,
    required this.expand,
    required this.onTap,
    this.bottomBar,
  });

  TextSpan _tapSpan(
    BuildContext context, {
    required String? text,
    required TextStyle? style,
    required VoidCallback onTap,
    bool underline = true,
  }) {
    return TextSpan(
      text: text,
      style: style?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: underline ? Theme.of(context).colorScheme.primary : null,
      ),
      recognizer: TapGestureRecognizer()..onTap = onTap,
    );
  }

  TextSpan _linkSpan(BuildContext context, {required String? text, required TextStyle? style, required String url}) {
    if (!url.startsWith('https://') && !url.startsWith('http://')) {
      url = 'https://$url';
    }
    return _tapSpan(context, text: text, style: style, onTap: () => openUri(url));
  }

  TextSpan _mentionSpan(
    BuildContext context, {
    required String? text,
    required TextStyle? style,
    required String screenName,
  }) {
    return _tapSpan(
      context,
      text: text,
      style: style,
      underline: false,
      onTap: () {
        Navigator.pushNamed(context, routeProfile, arguments: ProfileScreenArguments(null, screenName, null));
      },
    );
  }

  InlineSpan entityPlaceHolderReplace(BuildContext context, EntityPlaceHolderTextSpan placeHolder) {
    final key = placeHolder.entityKey;
    if (!article.entities.containsKey(key)) {
      return placeHolder;
    }

    final entity = article.entities[key];
    if (entity is LinkEntity) {
      return _linkSpan(context, text: placeHolder.text, style: placeHolder.style, url: entity.url);
    }
    return placeHolder;
  }

  InlineSpan replacePlaceHolders(BuildContext context, InlineSpan span) {
    if (span is TextSpan) {
      if (span is EntityPlaceHolderTextSpan) {
        return entityPlaceHolderReplace(context, span);
      }

      if (span is DataUrlTextSpan) {
        return _linkSpan(context, text: span.text, style: span.style, url: span.url);
      }

      if (span is DataMentionTextSpan) {
        return _mentionSpan(context, text: span.text, style: span.style, screenName: span.screenName);
      }

      if (span.children != null && span.children!.isNotEmpty) {
        final newChildren = span.children!.map((child) => replacePlaceHolders(context, child)).toList();
        return TextSpan(text: span.text, style: span.style, children: newChildren);
      }

      return span;
    }

    return span;
  }

  List<Widget> _buildParagraphSpans(BuildContext context) {
    final result = <Widget>[];

    int orderedListItemIndex = 0;
    for (int i = 0; i < article.textParts.length; i++) {
      EdgeInsets padding;
      void addListItem(EdgeInsets padding, Widget prefix, InlineSpan textSpan) {
        result.add(
          Padding(
            padding: padding,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                prefix,
                Expanded(child: SelectableText.rich(TextSpan(children: [textSpan]))),
              ],
            ),
          ),
        );
      }

      final spans = replacePlaceHolders(context, article.textParts[i].inlineSpan);

      switch (article.textParts[i].type) {
        case ArticleTextBlockType.unorderedListItem:
          padding = const EdgeInsets.fromLTRB(6.0, 4.0, 0.0, 4.0);
          addListItem(padding, const Text("• "), spans);
          orderedListItemIndex = 0;
          break;
        case ArticleTextBlockType.orderedListItem:
          padding = const EdgeInsets.fromLTRB(6.0, 4.0, 0.0, 4.0);
          addListItem(padding, Text("${orderedListItemIndex + 1}. "), spans);
          orderedListItemIndex++;
          break;
        case ArticleTextBlockType.headerTwo:
          padding = const EdgeInsets.symmetric(vertical: 16.0);
          orderedListItemIndex = 0;
          break;
        case ArticleTextBlockType.blockquote:
          final colorScheme = Theme.of(context).colorScheme;
          padding = const EdgeInsets.symmetric(vertical: 8.0);
          result.add(
            Padding(
              padding: padding,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12.0, 8.0, 8.0, 8.0),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Color.alphaBlend(
                        colorScheme.onSurface.withValues(alpha: 0.08),
                        colorScheme.surfaceContainer,
                      ),
                      width: 4.0,
                    ),
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                child: SelectableText.rich(TextSpan(children: [spans])),
              ),
            ),
          );
          orderedListItemIndex = 0;
          break;
        case ArticleTextBlockType.unstyled:
        default:
          padding = const EdgeInsets.symmetric(vertical: 8.0);
          orderedListItemIndex = 0;
      }

      if (article.textParts[i].type != ArticleTextBlockType.atomic &&
          article.textParts[i].type != ArticleTextBlockType.unorderedListItem &&
          article.textParts[i].type != ArticleTextBlockType.orderedListItem &&
          article.textParts[i].type != ArticleTextBlockType.blockquote) {
        result.add(
          Padding(
            padding: padding,
            child: SelectableText.rich(TextSpan(children: [spans])),
          ),
        );
      }

      for (final entityRange in article.textParts[i].entityRanges) {
        final w = article.entities[entityRange["key"]];
        if (w == null || w is LinkEntity) continue;
        result.add(Padding(padding: EdgeInsets.symmetric(vertical: 4.0), child: w.toWidget(context)));
      }
    }

    return result;
  }

  Widget _buildCollapsed(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.coverMedia != null) article.coverMedia!.toWidget(context),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: titleStyle ?? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (article.previewText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        article.previewText,
                        style: previewStyle ?? theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!expand) return _buildCollapsed(context);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (article.coverMedia != null) ...[
            Padding(padding: const EdgeInsets.only(bottom: 16.0), child: article.coverMedia!.toWidget(context)),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              article.title,
              style: titleStyle ?? theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (bottomBar != null) ...[
            bottomBar!,
            Divider(height: 1, color: theme.colorScheme.surfaceBright.withAlpha(150)),
            const SizedBox(height: 16),
          ],
          ..._buildParagraphSpans(context),
        ],
      ),
    );
  }
}
