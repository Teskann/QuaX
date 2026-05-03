part of 'media_grid_item.dart';

class PhotoGridItem extends MediaGridItem {
  const PhotoGridItem({
    required super.tweetId,
    required super.username,
    required super.thumbnailUrl,
    required super.aspectRatio,
    required super.mediaIndex,
    required super.media,
  });

  @override
  Widget toWidget(BuildContext context) {
    return ExtendedImage.network(
      '$thumbnailUrl:medium',
      cache: true,
      fit: BoxFit.cover,
    );
  }
}