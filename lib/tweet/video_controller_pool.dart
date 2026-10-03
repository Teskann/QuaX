import 'dart:async';
import 'dart:collection';

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter/scheduler.dart';
import 'package:quax/utils/iterables.dart';
import 'package:quax/tweet/video_quality.dart';

/// One cached video player: a [BetterPlayerController] together with the
/// resolved download URL and the selectable [qualities]. The pool owns this
/// controller and is the only thing allowed to dispose it (on LRU eviction) —
/// widgets attach/detach but never dispose. The
/// controller is created with `autoDispose: false`, so the [BetterPlayer]
/// widget's own teardown is a no-op and the player survives across screens.
class PooledVideo {
  final BetterPlayerController controller;
  final String? downloadUrl;
  final List<TweetVideoQuality> qualities;

  /// Completes once the player can play, or fails when it can't (e.g. no
  /// decoder left). The player is handed out before that, so it can be released
  /// while still loading.
  final Future<void> ready;

  /// False for muted looping GIFs, which the single-audible-video policy leaves
  /// playing.
  final bool pausableByPolicy;

  Future<void>? _released;

  PooledVideo({
    required this.controller,
    required this.downloadUrl,
    required this.qualities,
    required this.ready,
    required this.pausableByPolicy,
  });

  // A released controller throws when asked about its state.
  bool get isPlaying => _released == null && (controller.isPlaying() ?? false);
  bool get isInitialized => _released == null && (controller.isVideoInitialized() ?? false);

  void pause() {
    if (isPlaying) controller.pause();
  }

  /// Completes once the native player, and its decoder, are released.
  Future<void> dispose() => _released ??= _release(controller);

  // `BetterPlayerController.dispose()` returns before the native player is
  // released, so release the underlying player ourselves to know when it is.
  static Future<void> _release(BetterPlayerController controller) async {
    final player = controller.videoPlayerController;
    controller.videoPlayerController = null;
    controller.dispose(forceDispose: true);
    await player?.dispose();
  }
}

class _Entry {
  final _result = Completer<PooledVideo>();
  final _evicted = Completer<void>();

  /// The player once it can play.
  PooledVideo? value;

  /// The widgets showing this player, each with what to do if it is evicted.
  final Map<Object, VoidCallback> holders = {};

  _Entry() {
    // Nobody may be waiting for a player evicted before it was ready.
    _result.future.ignore();
  }

  Future<PooledVideo> get future => _result.future;
  bool get isEvicted => _evicted.isCompleted;
  bool get isFullScreen => value?.controller.isFullScreen ?? false;

  void evict() {
    if (!_evicted.isCompleted) _evicted.complete();
    if (!_result.isCompleted) _result.completeError(const VideoEvictedException());
  }

  /// Creates the player, hands it out once ready, and keeps it until evicted.
  /// Completes once it is released.
  Future<void> run(Future<PooledVideo> Function() create) async {
    PooledVideo? video;
    try {
      if (isEvicted) return;
      video = await create();
      await Future.any([video.ready, _evicted.future]);
      if (isEvicted) return;
      value = video;
      _result.complete(video);
      await _evicted.future;
    } catch (error, stackTrace) {
      if (!_result.isCompleted) _result.completeError(error, stackTrace);
    } finally {
      await video?.dispose();
    }
  }
}

/// The player was evicted from the pool before it was ready.
class VideoEvictedException implements Exception {
  const VideoEvictedException();
}

/// An LRU cache of video players, keyed by `tweetId:mediaIndex`.
///
/// Why this exists: navigating to a tweet (or scrolling back to it) used to build
/// a brand-new player and restart playback from zero. Keeping the player alive
/// lets the same video keep playing across screens and avoids re-fetching it. A
/// single instance is provided app-wide.
///
/// Each player is heavy (a hardware decoder plus its buffer on the Java heap),
/// so never more than [maxSize] of them are alive, a budget that depends on the
/// device (see `video_player_budget.dart`). A player counts from its creation
/// until its native player is released, and one asked for while the budget is
/// used up is only created once another one is released.
///
/// Lifetime contract:
///  - [acquire] returns the cached controller (creating it on a miss) and marks
///    it in use; concurrent callers for the same key share one player.
///  - [release] marks a widget as gone but does NOT dispose — the entry stays
///    cached for instant reuse.
///  - Only eviction disposes. When the pool is full, after the frame, the
///    oldest player goes, preferring one no widget shows, then one that is off
///    screen. A widget whose player is evicted is told through its `onEvicted`
///    callback, and the player is only disposed after the next frame, once that
///    widget dropped it.
class VideoControllerPool {
  final int maxSize;
  final void Function(VoidCallback) _afterFrame;
  final Map<String, _Entry> _entries = {};
  final Map<String, Set<Object>> _visibleTokens = {};
  final Queue<Completer<void>> _waitingForSlot = Queue();
  int _alive = 0;
  bool _trimScheduled = false;

  VideoControllerPool({required this.maxSize, void Function(VoidCallback)? afterFrame})
      : _afterFrame = afterFrame ?? _afterNextFrame;

  static void _afterNextFrame(VoidCallback callback) {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => callback())
      ..scheduleFrame();
  }

  /// How many players exist, released ones excepted.
  int get alive => _alive;

  bool contains(String key) => _entries.containsKey(key);
  bool holds(String key, Object holder) => _entries[key]?.holders.containsKey(holder) ?? false;
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

  /// Pause every other policy-pausable player so only [active] is audible.
  void pauseOthers(PooledVideo active) {
    for (final entry in _entries.values) {
      final video = entry.value;
      if (video == null || identical(video, active)) continue;
      if (!video.pausableByPolicy) continue;
      video.pause();
    }
  }

  Future<PooledVideo> acquire(String key, Object holder, Future<PooledVideo> Function() create,
      {VoidCallback onEvicted = _ignore}) {
    var entry = _entries.remove(key) ?? _start(create);
    _entries[key] = entry;
    entry.holders[holder] = onEvicted;
    // Widgets acquire while building, when the evicted ones can't rebuild yet.
    if (!_trimScheduled) {
      _trimScheduled = true;
      _afterFrame(_trim);
    }
    return entry.future;
  }

  static void _ignore() {}

  _Entry _start(Future<PooledVideo> Function() create) {
    final entry = _Entry();
    () async {
      await _takeSlot();
      await entry.run(create);
      _giveSlot();
    }();
    return entry;
  }

  Future<void> _takeSlot() {
    if (_alive < maxSize) {
      _alive++;
      return Future.value();
    }
    final slot = Completer<void>();
    _waitingForSlot.add(slot);
    return slot.future;
  }

  // A released slot goes straight to the next waiting player, so a new
  // creation can never slip in between and exceed the budget.
  void _giveSlot() {
    if (_waitingForSlot.isNotEmpty) {
      _waitingForSlot.removeFirst().complete();
    } else {
      _alive--;
    }
  }

  void _trim() {
    _trimScheduled = false;
    while (_entries.length > maxSize && evictOldest(except: _entries.keys.last)) {}
  }

  void release(String key, Object holder) {
    _entries[key]?.holders.remove(holder);
  }

  void invalidate(String key) {
    final entry = _entries[key];
    if (entry == null) return;
    // Don't force-dispose a controller another widget still holds (the same video
    // live in two places): only drop and dispose it once no widget references it.
    // The caller releases its own ref before invalidating, so the common
    // single-holder case still disposes here.
    if (entry.holders.isNotEmpty) return;
    _entries.remove(key);
    _visibleTokens.remove(key);
    entry.evict();
  }

  /// Evicts the oldest player other than [except]'s, to make room for it.
  /// Returns false when there is nothing to evict.
  bool evictOldest({required String except}) {
    final candidates = _entries.entries.where((e) => e.key != except && !e.value.isFullScreen).toList();
    final victim = candidates.firstWhereOrNull((e) => e.value.holders.isEmpty) ??
        candidates.firstWhereOrNull((e) => !anyVisible(e.key)) ??
        candidates.firstOrNull;
    if (victim == null) return false;

    _entries.remove(victim.key);
    _visibleTokens.remove(victim.key);
    final entry = victim.value;
    if (entry.holders.isEmpty) {
      entry.evict();
      return true;
    }
    _afterFrame(entry.evict);
    for (final onEvicted in entry.holders.values) {
      onEvicted();
    }
    return true;
  }
}
