part of 'media_grid_item.dart';

class VideoGridItem extends MediaGridItem {
  const VideoGridItem({
    required super.tweetId,
    required super.username,
    required super.thumbnailUrl,
    required super.aspectRatio,
    required super.mediaIndex,
    required super.media,
  });

  @override
  Widget toWidget(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        ExtendedImage.network(
          thumbnailUrl,
          cache: true,
          fit: BoxFit.cover,
        ),
        const FritterCenterPlayButton(
            backgroundColor: Colors.black54,
            iconColor: Colors.white,
            show: true,
            isPlaying: false,
            isFinished: false,
            size: 40
        ),
      ],
    );
  }
}