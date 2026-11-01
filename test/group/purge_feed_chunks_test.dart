import 'package:flutter_test/flutter_test.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/feed_cache.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/group_screen.dart';

import 'open_feed.dart';

Future<List<String>> _storedHashes() async => (await (await Repository.readOnly()).query(tableFeedGroupChunk))
    .map((e) => e['hash'] as String)
    .toList();

void main() {
  useFreshDatabase();

  test('Should drop only the cached pages of the chunks no feed is made of anymore', () async {
    final repository = await Repository.writable();
    await repository.insert(tableSubscription, flutterDev.toMap());
    final mainFeed = feedChunksOf(await readSubscriptionGroup(repository, '-1')).single.hash;
    for (final hash in [mainFeed, 'unsubscribed']) {
      await repository.insert(tableFeedGroupChunk, {'hash': hash, 'response': '[]'});
    }

    await purgeOrphanFeedChunks(repository);

    expect(await _storedHashes(), [mainFeed],
        reason: 'The main feed keeps its cache, while a chunk of accounts no longer followed together is dropped');
  });
}
