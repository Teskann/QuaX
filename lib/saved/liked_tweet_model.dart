import 'dart:convert';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';

class LikedTweetModel extends Store<List<LikedTweet>> {
  static final log = Logger('LikedTweetModel');

  LikedTweetModel() : super([]);

  bool isLiked(String id) {
    return state.any((e) => e.id == id);
  }

  Future<void> listLikedTweets() async {
    log.info('Listing liked tweets');

    await execute(() async {
      var database = await Repository.readOnly();

      return (await database.query(tableLikedTweet, orderBy: 'liked_at DESC'))
          .map((e) => LikedTweet.fromMap(e))
          .toList();
    });
  }

  /// Reloads without entering the loading state, so the current list stays visible
  /// until the fresh data is ready (used for pull-to-refresh).
  Future<void> refreshLikedTweets() async {
    log.info('Refreshing liked tweets');

    var database = await Repository.readOnly();

    var tweets =
        (await database.query(tableLikedTweet, orderBy: 'liked_at DESC')).map((e) => LikedTweet.fromMap(e)).toList();

    update(tweets, force: true);
  }

  Future<void> likeTweet(String id, String? user, Map<String, dynamic> content) async {
    log.info('Liking tweet with the ID $id');

    var database = await Repository.writable();
    var encodedContent = jsonEncode(content);

    // Idempotent: the same tweet can surface twice in a feed (e.g. a pinned/retweeted
    // copy and its older chronological one), so a second "like" of an id already present
    // must not throw on the primary key nor duplicate the in-memory entry.
    await database.insert(tableLikedTweet, {'id': id, 'user_id': user, 'content': encodedContent},
        conflictAlgorithm: ConflictAlgorithm.replace);
    update([LikedTweet(id: id, user: user, content: encodedContent), ...state.where((e) => e.id != id)], force: true);
  }

  Future<void> unlikeTweet(String id) async {
    log.info('Unliking tweet with the ID $id');

    var database = await Repository.writable();

    await database.delete(tableLikedTweet, where: 'id = ?', whereArgs: [id]);
    update(state.where((e) => e.id != id).toList(), force: true);
  }
}
