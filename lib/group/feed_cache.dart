import 'dart:convert';

import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';
import 'package:quax/utils/iterables.dart';
import 'package:sqflite/sqflite.dart';

List<TweetChain> chainsFromStoredChunks(List<Map<String, Object?>> storedChunks) {
  return storedChunks
      .map((e) => jsonDecode(e['response'] as String))
      .map((e) => List.from(e))
      .expand((e) => e.map((c) => TweetChain.fromJson(c)))
      .toList();
}

List<TweetChain> sortChainsNewestFirst(List<TweetChain> chains) {
  return chains.sorted((a, b) {
    var aCreatedAt = a.tweets[0].createdAt;
    var bCreatedAt = b.tweets[0].createdAt;

    if (aCreatedAt == null || bCreatedAt == null) {
      return 0;
    }

    return bCreatedAt.compareTo(aCreatedAt);
  }).toList();
}

/// Removes the duplicates and the chains already in [shown].
List<TweetChain> unseenChains(Iterable<TweetChain> chains, [Iterable<TweetChain> shown = const []]) {
  var seen = shown.map((e) => e.id).toSet();
  return chains.where((c) => seen.add(c.id)).toList();
}

Future<List<TweetChain>> readStoredChains(Database repository, String hash) async {
  var storedChunks =
      await repository.query(tableFeedGroupChunk, where: 'hash = ?', whereArgs: [hash], orderBy: 'rowid');
  return chainsFromStoredChunks(storedChunks);
}

/// Returns the cursor of the last page stored for this chunk.
Future<String?> readChunkCursor(Database repository, String hash) async {
  var rows = await repository.query(tableFeedGroupChunk,
      columns: ['cursor_bottom'], where: 'hash = ?', whereArgs: [hash], orderBy: 'rowid DESC', limit: 1);
  return rows.firstOrNull?['cursor_bottom'] as String?;
}

Future<void> storeChunkPage(Database repository, String hash, TweetStatus page, {required bool firstPage}) async {
  if (firstPage) {
    await repository.delete(tableFeedGroupChunk, where: 'hash = ?', whereArgs: [hash]);
  }
  // An empty page has no cursor, which marks the end of the chunk
  await repository.insert(tableFeedGroupChunk, {
    'hash': hash,
    'cursor_bottom': page.chains.isEmpty ? null : page.cursorBottom,
    'response': jsonEncode(page.chains.map((e) => e.toJson()).toList()),
  });
}

/// Returns null when no chunk has a next page.
String? feedCursorOf(Iterable<String?> chunkCursors) {
  var cursor = chunkCursors.nonNulls.join(' ');
  return cursor.isEmpty ? null : cursor;
}

/// Cached tweets for the given chunk [hashes], newest first.
Future<List<TweetChain>> readCachedChainsForHashes(Database repository, Iterable<String> hashes) async {
  var chains = <TweetChain>[];
  for (var hash in hashes) {
    chains.addAll(await readStoredChains(repository, hash));
  }
  return sortChainsNewestFirst(unseenChains(chains));
}

Future<String?> readFeedPosition(Database repository, String groupId) async {
  var rows = await repository.query(tableSubscriptionGroup,
      columns: ['feed_position'], where: 'id = ?', whereArgs: [groupId]);
  return rows.firstOrNull?['feed_position'] as String?;
}

Future<void> storeFeedPosition(Database repository, String groupId, String chainId) =>
    repository.update(tableSubscriptionGroup, {'feed_position': chainId}, where: 'id = ?', whereArgs: [groupId]);

/// Deletes the cache of the chunks that no feed uses anymore.
Future<void> purgeOrphanFeedChunks(Database repository) async {
  var ids = (await repository.query(tableSubscriptionGroup, columns: ['id'])).map((e) => e['id'] as String);
  var groups = await Future.wait(ids.map((id) => readSubscriptionGroup(repository, id)));
  var hashes = groups.expand(feedChunksOf).map((chunk) => chunk.hash).toSet();
  var stored = await repository.query(tableFeedGroupChunk, columns: ['hash'], distinct: true);
  var orphans = stored.map((e) => e['hash'] as String).where((hash) => !hashes.contains(hash)).toList();
  if (orphans.isEmpty) return;
  await repository.delete(tableFeedGroupChunk,
      where: 'hash IN (${List.filled(orphans.length, '?').join(', ')})', whereArgs: orphans);
}
