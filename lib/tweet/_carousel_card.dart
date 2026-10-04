import 'package:dart_twitter_api/twitter_api.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/tweet/_card_frame.dart';
import 'package:quax/tweet/_media.dart';

/// Unified card of type image_carousel_website, eg https://x.com/UEFA/status/2082854732020760880
class ImageCarouselCard extends StatelessWidget {
  final String uri;
  final List<Media> media;
  final String title;
  final String? subtitle;
  final String username;

  const ImageCarouselCard(
      {super.key,
      required this.uri,
      required this.media,
      required this.title,
      required this.subtitle,
      required this.username});

  /// Null when the card lacks what it takes to be drawn
  static ImageCarouselCard? fromUnifiedCard(Map<String, dynamic> unifiedCard, String username) {
    final String? uri = unifiedCard['destination_objects']?['browser_1']?['data']?['url_data']?['url'];
    final details = unifiedCard['component_objects']?['details_1']?['data'];
    final String? title = details?['title']?['content'];
    final List<dynamic> mediaList =
        unifiedCard['component_objects']?['swipeable_media_1']?['data']?['media_list'] ?? [];
    final media = mediaList
        .map((e) => unifiedCard['media_entities']?[e['id']])
        .whereType<Map<String, dynamic>>()
        .map(Media.fromJson)
        .toList();
    if (uri == null || title == null || media.isEmpty) {
      return null;
    }
    return ImageCarouselCard(
        uri: uri, media: media, title: title, subtitle: details?['subtitle']?['content'], username: username);
  }

  @override
  Widget build(BuildContext context) {
    return WebsiteCard(
      uri: uri,
      media: TweetMedia(media: media, username: username, sensitive: false, margin: EdgeInsets.zero),
      title: title,
      subtitle: subtitle,
    );
  }
}
