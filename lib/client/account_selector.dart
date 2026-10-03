import 'dart:math';

import 'package:quax/database/entities.dart';

/// Account selection policy.
///
/// Pure so it can be unit-tested without a database. Only accounts with a
/// credit left on the target endpoint can be picked. Credits are supplied via
/// [hasCredit] so this class stays free of global/in-memory state.
class AccountSelector {
  final List<Account> accounts;
  final bool Function(Account) hasCredit;

  AccountSelector(this.accounts, {bool Function(Account)? hasCredit}) : hasCredit = hasCredit ?? ((_) => true);

  Account? pick({required Set<String> exclude}) {
    final candidates = accounts.where((a) => !exclude.contains(a.id) && hasCredit(a)).toList();
    if (candidates.isEmpty) {
      return null;
    }
    return candidates[Random().nextInt(candidates.length)];
  }
}
