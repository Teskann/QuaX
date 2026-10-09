/// What a group feed does with one chunk when loading a page after the first.
sealed class ChunkPaging {
  const ChunkPaging();
}

/// The chunk has nothing left to load (or never had a cursor), so it is not searched at all.
class SkipChunk extends ChunkPaging {
  const SkipChunk();
}

/// The chunk is searched from [cursor], where the previous page stopped.
class SearchFromCursor extends ChunkPaging {
  final String cursor;

  const SearchFromCursor(this.cursor);
}

/// Decides how to page a chunk, given its stored rows for the cursor of the page being left.
ChunkPaging decideChunkPaging(List<Map<String, Object?>> storedRows) {
  var cursor = storedRows.map((row) => row['cursor_bottom']).whereType<String>().firstOrNull;
  return cursor == null ? const SkipChunk() : SearchFromCursor(cursor);
}

/// The row to store when a chunk's search failed, so the next page retries from [searchCursor] instead of from the
/// top. Null when there was no cursor to carry (first page), which leaves the chunk skipped on later pages.
Map<String, Object?>? carryForwardRow(
    {required int nextCursorId, required String hash, required String? searchCursor}) {
  if (searchCursor == null) return null;
  return {
    'cursor_id': nextCursorId,
    'hash': hash,
    'cursor_top': null,
    'cursor_bottom': searchCursor,
    'response': '[]',
  };
}
