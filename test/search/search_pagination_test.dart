import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:quax/search/search_model.dart';

void main() {
  group('SearchPagination', () {
    test('Should send nothing to X while the search is empty', () async {
      final sent = <String>[];
      final pagination = SearchPagination<String>((query, cursor) async {
        sent.add(query);
        return (items: [query], nextCursor: null);
      });
      addTearDown(pagination.dispose);

      pagination.pagingController.fetchNextPage();
      await pumpEventQueue();

      expect(sent, isEmpty, reason: 'An empty search has no results, so it should not cost a request');
      expect(pagination.pagingController.value.items, isEmpty, reason: 'An empty search lists nothing');
    });

    test('Should load the new query from its first page when the query changes', () async {
      final sent = <(String, String?)>[];
      final pagination = SearchPagination<String>((query, cursor) async {
        sent.add((query, cursor));
        return (items: ['$query ${sent.length}'], nextCursor: 'next');
      }, initialQuery: 'flutter');
      addTearDown(pagination.dispose);

      pagination.pagingController.fetchNextPage();
      await pumpEventQueue();
      pagination.pagingController.fetchNextPage();
      await pumpEventQueue();
      pagination.updateQuery('dart');
      pagination.pagingController.fetchNextPage();
      await pumpEventQueue();

      expect(sent, [('flutter', null), ('flutter', 'next'), ('dart', null)],
          reason: 'Pages follow their cursor, and a new query starts over without the cursor of the old one');
      expect(pagination.pagingController.value.items, ['dart 3'],
          reason: 'The results of the old query should be dropped');
    });

    test('Should not reload when the same query is set again', () async {
      var fetches = 0;
      final pagination = SearchPagination<String>((query, cursor) async {
        fetches++;
        return (items: [query], nextCursor: null);
      }, initialQuery: 'flutter');
      addTearDown(pagination.dispose);

      pagination.pagingController.fetchNextPage();
      await pumpEventQueue();
      pagination.updateQuery('flutter');
      pagination.pagingController.fetchNextPage();
      await pumpEventQueue();

      expect(fetches, 1, reason: 'Typing the same query again should keep the results already loaded');
    });
  });
}
