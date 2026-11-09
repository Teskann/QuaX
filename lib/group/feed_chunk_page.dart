import 'package:quax/client/client.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/feed_chunk.dart';
import 'package:quax/group/unrelated_tweets.dart';
import 'package:quax/utils/paging.dart';
import 'package:sqflite/sqflite.dart';

class ChunkPage {
  /// Falls back to the stored tweets when the first page fails.
  final List<TweetChain> tweets;
  final List<TweetChain> answered;
  final String? cursor;
  final PagingError? error;
  final bool failed;
  final bool unrelated;

  static const ended =
      ChunkPage(tweets: [], answered: [], cursor: null, error: null, failed: false, unrelated: false);

  const ChunkPage(
      {required this.tweets,
      required this.answered,
      required this.cursor,
      required this.error,
      required this.failed,
      required this.unrelated});
}

/// Each chunk resumes from its own last cursor. A chunk without a cursor has nothing more to load.
Future<ChunkPage> loadChunkPage(Database repository, FeedChunk chunk, {required bool firstPage}) async {
  var storedCursor = await readChunkCursor(repository, chunk.hash);
  if (!firstPage && storedCursor == null) {
    return ChunkPage.ended;
  }
  TweetStatus result;
  try {
    result = await _loadPage(chunk, firstPage ? null : storedCursor);
  } catch (e, stackTrace) {
    var stored = firstPage ? await readStoredChains(repository, chunk.hash) : const <TweetChain>[];
    return ChunkPage(
        tweets: stored,
        answered: const [],
        cursor: storedCursor,
        error: PagingError(e, stackTrace),
        failed: true,
        unrelated: false);
  }
  await storeChunkPage(repository, chunk.hash, result, firstPage: firstPage);
  var answeredError = result.error;
  return ChunkPage(
      tweets: result.chains,
      answered: result.chains,
      cursor: await readChunkCursor(repository, chunk.hash),
      error: answeredError == null ? null : PagingError(answeredError, StackTrace.current),
      failed: false,
      unrelated: _containsUnrelatedTweets(chunk, result));
}

Future<TweetStatus> _loadPage(FeedChunk chunk, String? cursor) => switch (chunk) {
      SearchFeedChunk(:final query) => Twitter.searchTweets(query, cursor: cursor),
      CommunityFeedChunk(:final community) =>
        Twitter.getCommunityTweets(community.id, cursor: cursor, ranking: CommunityRanking.latest),
    };

bool _containsUnrelatedTweets(FeedChunk chunk, TweetStatus page) => switch (chunk) {
      SharedSearchFeedChunk(:final subscriptions) => feedContainsUnrelatedTweets(page, subscriptions),
      // Anyone in the community can post there
      CommunityFeedChunk() => false,
      // A list shows its members, who need not be followed in the group
      ListFeedChunk() => false,
    };
