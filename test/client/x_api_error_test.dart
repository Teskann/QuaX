import 'package:flutter_test/flutter_test.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/client.dart';

import '../fixtures.dart';

void main() {
  group('parseSearchTimeline', () {
    test('Should throw the error X answered instead of a timeline, rather than show an empty search', () {
      final body = fixture('SearchTimeline', 'min-faves-10000', unstable: true).body;

      expect(() => Twitter.parseSearchTimeline(body, product: 'Top'),
          throwsA(isA<XApiError>().having((e) => e.isRejectedSearch, 'isRejectedSearch', isTrue)),
          reason: 'X refused to rank a filter alone on the Top tab: that is not an empty result');
    });

    test('Should keep the tweets X sent along with an error, and the error with them', () {
      final body =
          withXError(fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body, internalXError);

      final status = Twitter.parseSearchTimeline(body);

      expect(status.chains, isNotEmpty, reason: 'The tweets X sent should still be shown');
      expect(status.error?.message, 'Dependency: Unspecified', reason: 'The error should come along to be shown too');
    });

    test('Should not carry any error when X listed none', () {
      final status =
          Twitter.parseSearchTimeline(fixture('SearchTimeline', 'from-flutterdev-filter-links', unstable: true).body);

      expect(status.error, isNull, reason: 'A plain answer of X has nothing to warn about');
    });
  });

  group('XApiError', () {
    test('Should tell a search X refused to run from any other error of X', () {
      final refused = XApiError('', kind: 'Validation', path: ['search_by_raw_query', 'search_timeline']);
      final otherValidation = XApiError('', kind: 'Validation', path: ['user', 'result']);
      final otherKind = XApiError('', kind: 'Operational', path: ['search_by_raw_query', 'search_timeline']);

      expect(refused.isRejectedSearch, isTrue, reason: 'X refused the search query itself');
      expect(otherValidation.isRejectedSearch, isFalse,
          reason: 'A request QuaX builds alone that X refuses is a bug of QuaX, not a search to change');
      expect(otherKind.isRejectedSearch, isFalse, reason: 'Only a refusal of the query says the search is at fault');
    });
  });
}
