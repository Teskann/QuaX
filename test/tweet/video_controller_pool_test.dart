import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/video_controller_pool.dart';

void main() {
  Future<PooledVideo> neverFinishesBuilding() => Completer<PooledVideo>().future;
  final widget = Object();
  VideoControllerPool poolOf(int maxSize) => VideoControllerPool(maxSize: maxSize, afterFrame: (dispose) => dispose());

  group('VideoControllerPool.acquire()', () {
    test('Should keep a player so it is not built again on the next call', () {
      final pool = poolOf(5);
      final first = pool.acquire('tweet:0', widget, neverFinishesBuilding);
      final second = pool.acquire('tweet:0', widget, neverFinishesBuilding);

      expect(identical(first, second), isTrue,
          reason: 'Scrolling back to a tweet should reuse the player that is already playing, '
              'rather than build a new one and start the video again from the beginning');
    });

    test('Should remove the oldest unused player when the pool is full', () {
      final pool = poolOf(2);
      for (final key in ['a', 'b', 'c']) {
        pool.acquire(key, widget, neverFinishesBuilding);
        pool.release(key, widget);
      }

      expect(pool.contains('a'), isFalse,
          reason: 'Player a is the oldest unused one, so it should be the one dropped');
      expect(pool.contains('b'), isTrue,
          reason: 'Only one player has to go to get back to the size limit of 2, so b should stay');
      expect(pool.contains('c'), isTrue,
          reason: 'Player c is the newest one, so it should stay');
    });

    test('Should count a player as the newest again when it is asked for again', () {
      final pool = poolOf(2);
      pool.acquire('a', widget, neverFinishesBuilding);
      pool.release('a', widget);
      pool.acquire('b', widget, neverFinishesBuilding);
      pool.release('b', widget);

      pool.acquire('a', widget, neverFinishesBuilding);
      pool.release('a', widget);
      pool.acquire('c', widget, neverFinishesBuilding);
      pool.release('c', widget);

      expect(pool.contains('a'), isTrue,
          reason: 'Player a was used more recently than player b, so a should stay and b should '
              'be the one dropped');
      expect(pool.contains('b'), isFalse,
          reason: 'Player b has not been used since it was added, so it should now count as the '
              'oldest one and go first');
    });

    test('Should remove the oldest player even when a widget shows it, once the pool is full', () {
      final pool = poolOf(1);
      var evicted = false;
      pool.acquire('onscreen', widget, neverFinishesBuilding, onEvicted: () => evicted = true);
      pool.acquire('other', Object(), neverFinishesBuilding);

      expect(pool.contains('onscreen'), isFalse,
          reason: 'The size is the number of players the device can afford: going over it '
              'exhausts the Java heap and crashes the app, so the oldest player has to go');
      expect(evicted, isTrue,
          reason: 'The widget showing the removed player has to be told, so it stops using it '
              'and falls back to its poster');
    });

    test('Should wait for the end of the frame to remove a player', () {
      final frameEnd = <VoidCallback>[];
      final pool = VideoControllerPool(maxSize: 1, afterFrame: frameEnd.add);
      var evicted = false;
      pool.acquire('onscreen', widget, neverFinishesBuilding, onEvicted: () => evicted = true);
      pool.acquire('other', Object(), neverFinishesBuilding);

      expect(evicted, isFalse,
          reason: 'Players are asked for while widgets build, when the evicted widget cannot be '
              'rebuilt yet: telling it then throws and leaked the player it was holding');

      for (final callback in [...frameEnd]) {
        callback();
      }
      expect(evicted, isTrue, reason: 'Once the frame is over, the oldest player should go');
    });

    test('Should never remove the player that was just asked for', () {
      final pool = poolOf(1);
      pool.acquire('only', widget, neverFinishesBuilding);

      expect(pool.contains('only'), isTrue,
          reason: 'Even the smallest budget has room for the video being opened');
    });

    test('Should remove a player no widget shows before one that a widget shows', () {
      final pool = poolOf(2);
      pool.acquire('shown', widget, neverFinishesBuilding);
      final scrolledAway = Object();
      pool.acquire('unused', scrolledAway, neverFinishesBuilding);
      pool.release('unused', scrolledAway);

      pool.acquire('new', Object(), neverFinishesBuilding);

      expect(pool.contains('shown'), isTrue,
          reason: 'Player shown is older, but a widget still uses it, so the unused one should go '
              'first to avoid replacing a video with its poster');
      expect(pool.contains('unused'), isFalse,
          reason: 'No widget uses this player, so dropping it costs nothing');
    });

    test('Should remove an off-screen player before a visible one', () {
      final pool = poolOf(2);
      final visible = Object();
      pool.acquire('visible', visible, neverFinishesBuilding);
      pool.markVisible('visible', visible);
      pool.acquire('hidden', Object(), neverFinishesBuilding);

      pool.acquire('new', Object(), neverFinishesBuilding);

      expect(pool.contains('visible'), isTrue,
          reason: 'Player visible is older, but it is on screen, so it should stay');
      expect(pool.contains('hidden'), isFalse,
          reason: 'This player is still held by a widget but off screen, so it should go before '
              'the one being watched');
    });
  });

  group('VideoControllerPool.evictOldest()', () {
    test('Should free a player for a video whose own player could not be allocated', () {
      final pool = poolOf(5);
      pool.acquire('old', Object(), neverFinishesBuilding);
      pool.acquire('failing', widget, neverFinishesBuilding);

      expect(pool.evictOldest(except: 'failing'), isTrue,
          reason: 'Another player exists, so one should be freed');
      expect(pool.contains('old'), isFalse, reason: 'The oldest player should be the one freed');
      expect(pool.contains('failing'), isTrue,
          reason: 'The player asking for room should never be the one freed');
    });

    test('Should return false when there is no other player to free', () {
      final pool = poolOf(5);
      pool.acquire('failing', widget, neverFinishesBuilding);

      expect(pool.evictOldest(except: 'failing'), isFalse,
          reason: 'Nothing else is alive, so nothing can be freed');
    });
  });

  group('VideoControllerPool.release()', () {
    test('Should keep the player in the pool for later reuse', () {
      final pool = poolOf(5);
      pool.acquire('tweet:0', widget, neverFinishesBuilding);
      pool.release('tweet:0', widget);

      expect(pool.contains('tweet:0'), isTrue,
          reason: 'This method only says that no widget is showing the video, so the player '
              'should stay cached. Only being dropped from the pool should close it');
    });
  });

  group('VideoControllerPool.invalidate()', () {
    test('Should do nothing while a widget still holds the player', () {
      final pool = poolOf(5);
      final feed = Object();
      pool.acquire('shared', feed, neverFinishesBuilding);
      pool.acquire('shared', widget, neverFinishesBuilding);
      pool.release('shared', widget);

      pool.invalidate('shared');

      expect(pool.contains('shared'), isTrue,
          reason: 'The same video can be on screen in two places, for example in the feed and in '
              'the open tweet, so one of them closing should leave the other one playing');
    });

    test('Should remove the player once nothing uses it', () {
      final pool = poolOf(5);
      pool.acquire('stale', widget, neverFinishesBuilding);
      pool.release('stale', widget);

      pool.invalidate('stale');

      expect(pool.contains('stale'), isFalse,
          reason: 'This method exists to force a rebuild, for example after a quality change, so '
              'with no widget left it should really drop the player');
    });
  });

  group('VideoControllerPool.anyVisible()', () {
    test('Should stay true while at least one tile says the key is visible', () {
      final pool = poolOf(5);
      final tileA = Object();
      final tileB = Object();

      pool.markVisible('tweet:0', tileA);
      pool.markVisible('tweet:0', tileB);
      pool.markHidden('tweet:0', tileA);

      expect(pool.anyVisible('tweet:0'), isTrue,
          reason: 'The same video shown in two places should stay visible until the last tile '
              'hides, otherwise it stops playing while still on screen');

      pool.markHidden('tweet:0', tileB);
      expect(pool.anyVisible('tweet:0'), isFalse,
          reason: 'The last tile is gone, so the video is really off screen and this should turn '
              'false to let playback stop');
    });
  });

  group('VideoControllerPool.markHidden()', () {
    test('Should do nothing for a key that was never marked visible', () {
      final pool = poolOf(5);

      expect(() => pool.markHidden('unknown', Object()), returnsNormally,
          reason: 'Widgets are not removed in a fixed order, so a tile can report hidden after '
              'its key was already cleaned up, and that should be ignored rather than throw');
    });
  });

  group('VideoControllerPool, number of alive players', () {
    PooledVideo videoReadyWith(Future<void> ready) => PooledVideo(
          controller: BetterPlayerController(const BetterPlayerConfiguration()),
          downloadUrl: null,
          qualities: const [],
          ready: ready,
          pausableByPolicy: true,
        );

    test('Should not create a player while the budget is used up', () async {
      final pool = VideoControllerPool(maxSize: 1, afterFrame: (_) {});
      var created = 0;
      Future<PooledVideo> create() async {
        created++;
        return videoReadyWith(Future.value());
      }

      pool.acquire('a', widget, create);
      pool.acquire('b', Object(), create);
      await pumpEventQueue();

      expect(created, 1,
          reason: 'Player a is still alive, so creating b now would exceed the budget, even '
              'briefly, which is what exhausted the decoders and the memory while scrolling fast');
      expect(pool.alive, 1, reason: 'Only one player may be alive with a budget of 1');
    });

    test('Should create the waiting player once the evicted one is released', () async {
      final pool = poolOf(1);
      final created = <String>[];
      Future<PooledVideo> Function() create(String key) => () async {
            created.add(key);
            return videoReadyWith(Future.value());
          };

      pool.acquire('a', widget, create('a'));
      await pumpEventQueue();
      pool.acquire('b', Object(), create('b'));
      await pumpEventQueue();

      expect(created, ['a', 'b'],
          reason: 'Evicting a frees the slot, so b should be created right after a is released');
      expect(pool.alive, 1, reason: 'a is released, so only b should count as alive');
    });

    test('Should release a player evicted while it was still loading', () async {
      final pool = poolOf(1);
      var bCreated = false;

      pool.acquire('a', widget, () async => videoReadyWith(Completer<void>().future));
      await pumpEventQueue();
      pool.acquire('b', Object(), () async {
        bCreated = true;
        return videoReadyWith(Future.value());
      });
      await pumpEventQueue();

      expect(bCreated, isTrue,
          reason: 'A player that never finishes loading must still be released when evicted, '
              'otherwise its decoder stays taken and the next player waits forever');
    });

    test('Should tell whoever waits for an evicted player that it is gone', () async {
      final pool = poolOf(1);
      final a = pool.acquire('a', widget, () async => videoReadyWith(Completer<void>().future));
      pool.acquire('b', Object(), () async => videoReadyWith(Future.value()));

      await expectLater(a, throwsA(isA<VideoEvictedException>()),
          reason: 'A widget waiting for a player that was evicted must not wait forever');
    });
  });

  group('PooledVideo.pause()', () {
    test('Should do nothing once the player is released', () async {
      final video = PooledVideo(
        controller: BetterPlayerController(const BetterPlayerConfiguration()),
        downloadUrl: null,
        qualities: const [],
        ready: Future.value(),
        pausableByPolicy: true,
      );
      await video.dispose();

      expect(video.pause, returnsNormally,
          reason: 'A widget can still pause its player right after the pool released it, and '
              'asking a released player whether it plays throws');
    });
  });
}
