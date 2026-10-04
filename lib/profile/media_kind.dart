import 'package:flutter_triple/flutter_triple.dart';

/// The web splits the Media tab in two requests, one for the videos and one for the photos.
enum MediaKind { videos, photos }

class MediaKindModel extends Store<MediaKind> {
  MediaKindModel() : super(MediaKind.videos);

  void select(MediaKind kind) => update(kind);
}
