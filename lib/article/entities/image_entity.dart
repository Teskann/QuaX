part of 'entity_value.dart';

class ImageEntity extends EntityValue {
  final String imageUrl;

  const ImageEntity({required this.imageUrl});

  @override
  Widget toWidget(BuildContext context) {
    return GestureDetector(
      child: ExtendedImage.network(imageUrl, fit: BoxFit.fitWidth),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TweetMediaView(
              initialIndex: 0,
              media: [createMediaFromUrl(imageUrl, null)],
              username: "Unknown",
              tweetMedia: false,
            ),
          ),
        );
      },
    );
  }
}
