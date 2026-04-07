import 'dart:convert';

import 'package:dart_twitter_api/twitter_api.dart';

import 'package:quax/article/article_entities.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/utils/iterables.dart';

class EntityMapParser {
  static Map<int, EntityValue> parse(dynamic json, List<dynamic> mediaEntitiesJson, String tweetIdStr, String user) {
    final List<dynamic> entityList;

    if (json is String) {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) {
        entityList = (decoded['entityMap'] as List<dynamic>? ?? <dynamic>[]);
      } else if (decoded is List<dynamic>) {
        entityList = decoded;
      } else {
        return <int, EntityValue>{};
      }
    } else if (json is Map<String, dynamic>) {
      entityList = (json['entityMap'] as List<dynamic>? ?? <dynamic>[]);
    } else if (json is List<dynamic>) {
      entityList = json;
    } else {
      return <int, EntityValue>{};
    }

    final result = <int, EntityValue>{};

    for (final item in entityList) {
      if (item is! Map<String, dynamic>) continue;

      final keyRaw = item['key'];
      final key = int.tryParse('$keyRaw');
      if (key == null) continue;

      final value = item['value'];
      if (value is! Map<String, dynamic>) continue;

      final type = (value['type'] ?? '').toString();
      final data = value['data'];

      if (data is! Map<String, dynamic>) continue;

      switch (type) {
        case 'MARKDOWN':
          final markdown = data['markdown']?.toString();
          if (markdown != null) {
            result[key] = MarkdownEntity(markdown: markdown);
          }
          break;

        case 'MEDIA':
          final mediaItems = data['mediaItems'];
          if (mediaItems is List && mediaItems.isNotEmpty) {
            final firstItem = mediaItems.first;
            if (firstItem is Map<String, dynamic>) {
              final mediaId = firstItem['mediaId']?.toString();
              if (mediaId != null && mediaId.isNotEmpty) {
                final res = mediaEntitiesJson.firstWhereOrNull((e) => e["media_id"] == mediaId);
                if (res["media_info"]?["__typename"] == "ApiImage") {
                  final url = res["media_info"]?["original_img_url"] ?? "";
                  result[key] = ImageEntity(imageUrl: url);
                } else if (res["media_info"]?["__typename"] == "ApiVideo") {
                  final variantsJson = res["media_info"]?["variants"];
                  List<Variant> variants = [];
                  if (variantsJson is List<dynamic>) {
                    variants = List.from(variantsJson.map((e) =>
                      Variant()
                        ..bitrate = e['bit_rate'] as int?
                        ..contentType = e['content_type'] as String?
                        ..url = e['url'] as String?));
                  }
                  result[key] = VideoEntity(
                    metadata: TweetVideoMetadata(
                      (res["media_info"]?["aspect_ratio"]?["numerator"] ?? 1.0) / (res["media_info"]?["aspect_ratio"]?["denominator"] ?? 1.0),
                      res["media_info"]?["preview_image"]?["original_img_url"],
                      TweetVideoMetadata.streamUrlsBuilderFromVariants(variants),
                    ),
                  );
                }
              }
            }
          }
          break;

        case 'LINK':
          final url = data['url']?.toString();
          if (url != null) {
            result[key] = LinkEntity(url: url);
          }
          break;

        case 'DIVIDER':
          result[key] = DividerEntity();
      }
    }

    return result;
  }
}
