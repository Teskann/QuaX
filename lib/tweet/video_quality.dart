/// One selectable progressive MP4 variant; [label] is e.g. `720p`.
class TweetVideoQuality {
  final String url;
  final String label;
  final int? bitrate;

  const TweetVideoQuality(this.url, this.label, {this.bitrate});
}

/// The file to download: the quality being played, or [bestUrl] when the player
/// is not on one of the [qualities] (e.g. an HLS stream).
String? downloadUrlFor(String? playingUrl, List<TweetVideoQuality> qualities, String? bestUrl) =>
    qualities.any((q) => q.url == playingUrl) ? playingUrl : bestUrl;
