import 'dart:convert';

import 'package:quax/database/entities.dart';

/// Tokens for the two built-in tabs. Folder tabs use their folder id as the token.
/// A token is also the filter value used by the Saved screen.
const savedTabAll = 'all';
const savedTabUnfiled = 'unfiled';

/// Resolves the ordered list of Saved tab tokens ([savedTabAll], [savedTabUnfiled]
/// and folder ids), honouring a stored custom order.
///
/// Tokens no longer valid (deleted folders) are dropped, and any token missing from
/// the stored order (newly created folders, or the built-ins) is appended in its
/// default position.
List<String> orderedSavedTabs(List<SavedTweetFolder> folders, String? storedOrder) {
  var defaults = [savedTabAll, ...folders.map((f) => f.id), savedTabUnfiled];
  var valid = {savedTabAll, savedTabUnfiled, ...folders.map((f) => f.id)};

  List<String> stored;
  try {
    stored = storedOrder == null || storedOrder.isEmpty
        ? <String>[]
        : (jsonDecode(storedOrder) as List).cast<String>();
  } catch (_) {
    stored = <String>[];
  }

  var order = stored.where(valid.contains).toList();
  for (var token in defaults) {
    if (!order.contains(token)) {
      order.add(token);
    }
  }

  return order;
}
