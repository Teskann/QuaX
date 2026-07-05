import 'dart:convert';

import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:logging/logging.dart';

class SavedTweetModel extends Store<List<SavedTweet>> {
  static final log = Logger('SavedTweetModel');

  SavedTweetModel() : super([]);

  bool isSaved(String id) {
    return state.any((e) => e.id == id);
  }

  String? folderOf(String id) {
    var match = state.where((e) => e.id == id);
    return match.isEmpty ? null : match.first.folderId;
  }

  Future<void> setFolder(String id, String? folderId) async {
    var database = await Repository.writable();

    await database.update(tableSavedTweet, {'folder_id': folderId}, where: 'id = ?', whereArgs: [id]);

    update(state.map((e) => e.id == id ? e.copyWith(folderId: folderId) : e).toList(), force: true);
  }

  Future<void> deleteSavedTweet(String id) async {
    var database = await Repository.writable();

    await database.delete(tableSavedTweet, where: 'id = ?', whereArgs: [id]);
    state.removeWhere((e) => e.id == id);

    update(state, force: true);
  }

  Future<void> listSavedTweets() async {
    log.info('Listing saved tweets');

    await execute(() async {
      var database = await Repository.readOnly();

      return (await database.query(tableSavedTweet, orderBy: 'saved_at DESC'))
          .map((e) => SavedTweet.fromMap(e))
          .toList();
    });
  }

  /// Reloads without entering the loading state, so the current list stays visible
  /// until the fresh data is ready (used for pull-to-refresh).
  Future<void> refreshSavedTweets() async {
    log.info('Refreshing saved tweets');

    var database = await Repository.readOnly();

    var tweets = (await database.query(tableSavedTweet, orderBy: 'saved_at DESC'))
        .map((e) => SavedTweet.fromMap(e))
        .toList();

    update(tweets, force: true);
  }

  Future<void> saveTweet(String id, String? user, Map<String, dynamic> content, {String? folderId}) async {
    log.info('Saving tweet with the ID $id');

    await execute(() async {
      var database = await Repository.writable();

      var encodedContent = jsonEncode(content);

      await database.insert(
          tableSavedTweet, {'id': id, 'user_id': user, 'content': encodedContent, 'folder_id': folderId});
      state.add(SavedTweet(id: id, user: user, content: encodedContent, folderId: folderId));

      return state;
    });
  }
}
