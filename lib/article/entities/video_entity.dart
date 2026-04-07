part of 'entity_value.dart';

class VideoEntity extends EntityValue {
  final TweetVideoMetadata metadata;

  const VideoEntity({required this.metadata});

  @override
  Widget toWidget(BuildContext context) {
    return TweetVideo(metadata: metadata, loop: false, username: "Unknown");
  }
}
