import 'package:quax/subscriptions/subscription_importer.dart';

/// Imports [following] accounts without reaching X, and remembers what it was asked.
class FakeImporter implements SubscriptionImporter {
  final int following;
  final int limit;
  final Object? error;
  final requests = <(String, int)>[];

  FakeImporter({this.following = 3, this.limit = 300, this.error});

  @override
  Future<SubscriptionImportSize> size(String screenName) async {
    if (error != null) {
      throw error!;
    }
    return SubscriptionImportSize(count: following, limit: limit);
  }

  @override
  Stream<ImportProgress> import(String screenName, int maxCount) async* {
    requests.add((screenName, maxCount));
    final total = following < maxCount ? following : maxCount;
    for (var collected = 1; collected <= total; collected++) {
      yield ImportProgress(collected: collected);
    }
    yield ImportProgress(collected: total, imported: total);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
