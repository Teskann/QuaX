import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';

/// One cached video player: the [VideoPlayerController] together with the
/// [ChewieController] wrapping it, plus the resolved download URL. The pool owns
/// this pair and is the only thing allowed to dispose it (on LRU eviction) —
/// widgets attach/detach but never dispose.
class PooledVideo {
  final VideoPlayerController videoController;
  final ChewieController chewieController;
  final String? downloadUrl;

  PooledVideo({
    required this.videoController,
    required this.chewieController,
    required this.downloadUrl,
  });

  void dispose() {
    chewieController.dispose();
    videoController.dispose();
  }
}

class _Entry {
  final Future<PooledVideo> future;
  PooledVideo? value;
  int refCount = 0;

  _Entry(this.future) {
    () async {
      try {
        value = await future;
      } catch (_) {}
    }();
  }

  void disposeWhenReady() {
    future.then((p) => p.dispose()).catchError((_) {});
  }
}

/// An LRU cache of video player controllers, keyed by `tweetId:mediaIndex`.
///
/// Why this exists: navigating to a tweet (or scrolling back to it) used to build
/// a brand-new controller and restart playback from zero. Keeping the controller
/// alive lets the same video keep playing across screens and avoids re-fetching
/// it. A single instance is provided app-wide.
///
/// Lifetime contract:
///  - [acquire] returns the cached pair (creating it on a miss) and marks it in
///    use; concurrent callers for the same key share one controller.
///  - [release] marks a widget as gone but does NOT dispose — the entry stays
///    cached for instant reuse.
///  - Only eviction disposes, and only entries with no live widget (refCount 0),
///    so a controller on screen is never disposed from under its widget.
class VideoControllerPool {
  final int maxSize;
  final Map<String, _Entry> _entries = {};
  final Map<String, Set<Object>> _visibleTokens = {};
  VideoControllerPool({this.maxSize = 5});
  bool contains(String key) => _entries.containsKey(key);
  PooledVideo? peek(String key) => _entries[key]?.value;

  void markVisible(String key, Object token) {
    (_visibleTokens[key] ??= {}).add(token);
  }

  void markHidden(String key, Object token) {
    final tokens = _visibleTokens[key];
    if (tokens == null) return;
    tokens.remove(token);
    if (tokens.isEmpty) _visibleTokens.remove(key);
  }

  bool anyVisible(String key) => _visibleTokens[key]?.isNotEmpty ?? false;

  Future<PooledVideo> acquire(String key, Future<PooledVideo> Function() create) {
    var entry = _entries.remove(key) ?? _Entry(create());
    _entries[key] = entry;
    entry.refCount++;
    _evict();
    return entry.future;
  }

  void invalidate(String key) {
    _entries.remove(key)?.disposeWhenReady();
    _visibleTokens.remove(key);
  }

  void release(String key) {
    final entry = _entries[key];
    if (entry == null) return;
    if (entry.refCount > 0) entry.refCount--;
    _evict();
  }

  void _evict() {
    while (_entries.length > maxSize) {
      String? victimKey;
      for (final e in _entries.entries) {
        if (e.value.refCount == 0) {
          victimKey = e.key;
          break;
        }
      }
      if (victimKey == null) break;
      _entries.remove(victimKey)!.disposeWhenReady();
      _visibleTokens.remove(victimKey);
    }
  }
}
