import 'dart:convert';

import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/utils/iterables.dart';
import 'package:sqflite/sqflite.dart';

/// Helpers for reading the tweets cached in [tableFeedGroupChunk]. Shared so the
/// feed loader and the "show cached tweets while loading" previews build their
/// chains identically.

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

/// Cached tweets for the given chunk [hashes], newest first.
Future<List<TweetChain>> readCachedChainsForHashes(Database repository, Iterable<String> hashes) async {
  var chains = <TweetChain>[];
  for (var hash in hashes) {
    var storedChunks = await repository.query(tableFeedGroupChunk,
        where: 'hash = ?', whereArgs: [hash], orderBy: 'created_at DESC');
    chains.addAll(chainsFromStoredChunks(storedChunks));
  }
  return sortChainsNewestFirst(chains);
}

/// Every cached tweet across all chunks, newest first and de-duplicated. Used to
/// preview the combined "All"/Following feed while its subscription list loads,
/// before the per-chunk hashes are known.
Future<List<TweetChain>> readAllCachedChains(Database repository) async {
  var storedChunks = await repository.query(tableFeedGroupChunk, orderBy: 'created_at DESC');
  var seen = <String>{};
  var chains = chainsFromStoredChunks(storedChunks).where((c) => seen.add(c.id)).toList();
  return sortChainsNewestFirst(chains);
}
