import 'package:dart_twitter_api/api/media/data/media.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/tweet/_video.dart';
import 'package:quax/tweet/_video_controls.dart';

part 'gif_grid_item.dart';
part 'video_grid_item.dart';
part 'photo_grid_item.dart';

sealed class MediaGridItem {
  final String tweetId;
  final String username;
  final String thumbnailUrl;
  final double aspectRatio;
  final int mediaIndex;
  final Media media;

  const MediaGridItem({
    required this.tweetId,
    required this.username,
    required this.thumbnailUrl,
    required this.aspectRatio,
    required this.mediaIndex,
    required this.media,
  });

  Widget toWidget(BuildContext context);
}

double _aspectRatioFor(Media m) {
  switch (m.type) {
    case 'photo':
      final w = m.sizes?.large?.w;
      final h = m.sizes?.large?.h;
      if (w == null || h == null || h == 0) return 1.0;
      return w / h;
    case 'video':
    case 'animated_gif':
      final ar = m.videoInfo?.aspectRatio;
      if (ar == null || ar.length < 2 || ar[1] == 0) return 1.0;
      return ar[0] / ar[1];
    default:
      return 1.0;
  }
}

MediaGridItem? _itemFor(Media m, String tweetId, String username, int mediaIndex) {
  final url = m.mediaUrlHttps;
  if (url == null) return null;
  final ar = _aspectRatioFor(m);
  switch (m.type) {
    case 'photo':
      return PhotoGridItem(
        tweetId: tweetId,
        username: username,
        thumbnailUrl: url,
        aspectRatio: ar,
        mediaIndex: mediaIndex,
        media: m,
      );
    case 'animated_gif':
      return GifGridItem(
        tweetId: tweetId,
        username: username,
        thumbnailUrl: url,
        aspectRatio: ar,
        mediaIndex: mediaIndex,
        media: m,
      );
    case 'video':
      return VideoGridItem(
        tweetId: tweetId,
        username: username,
        thumbnailUrl: url,
        aspectRatio: ar,
        mediaIndex: mediaIndex,
        media: m,
      );
    default:
      return null;
  }
}

List<MediaGridItem> mediaItemsFromChains(List<TweetChain> chains) {
  final out = <MediaGridItem>[];
  for (final chain in chains) {
    for (final tweet in chain.tweets) {
      final medias = tweet.extendedEntities?.media;
      if (medias == null || medias.isEmpty) continue;
      final tweetId = tweet.idStr;
      final username = tweet.user?.screenName;
      if (tweetId == null || username == null) continue;
      for (var i = 0; i < medias.length; i++) {
        final item = _itemFor(medias[i], tweetId, username, i);
        if (item != null) out.add(item);
      }
    }
  }
  return out;
}
