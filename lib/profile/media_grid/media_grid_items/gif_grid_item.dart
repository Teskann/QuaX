part of 'media_grid_item.dart';

class GifGridItem extends MediaGridItem {
  const GifGridItem({
    required super.tweetId,
    required super.username,
    required super.thumbnailUrl,
    required super.aspectRatio,
    required super.mediaIndex,
    required super.media,
  });

  @override
  Widget toWidget(BuildContext context) {
    return IgnorePointer(
      child: TweetVideo(
        metadata: TweetVideoMetadata.fromMedia(media),
        loop: true,
        alwaysPlay: true,
        disableControls: true,
        username: username,
      ),
    );
  }
}