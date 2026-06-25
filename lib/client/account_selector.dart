import 'dart:math';

import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';

/// Health-aware account selection policy.
///
/// Pure and clock-injected so it can be unit-tested without a database. An
/// account is "healthy" when it is not flagged not-found (auth broken) and not
/// currently rate-limited on the target endpoint. Rate-limit state is supplied
/// via [isRateLimited] so this class stays free of global/in-memory state.
class AccountSelector {
  final List<Account> accounts;
  final DateTime now;
  final bool Function(Account) isRateLimited;

  AccountSelector(this.accounts, this.now, {bool Function(Account)? isRateLimited})
      : isRateLimited = isRateLimited ?? ((_) => false);

  bool _notFoundFlagged(Account a) => a.lastNotFoundAt?.add(notFoundCooldown).isAfter(now) ?? false;

  bool _healthy(Account a) => !_notFoundFlagged(a) && !isRateLimited(a);

  /// Picks an account not already tried this request, preferring healthy ones
  /// but falling back to flagged accounts so a request is always attempted while
  /// any account remains. Returns null only when every account has been tried.
  Account? pick({required Set<String> exclude}) {
    final remaining = accounts.where((a) => !exclude.contains(a.id)).toList();
    if (remaining.isEmpty) {
      return null;
    }
    final healthy = remaining.where(_healthy).toList();
    final pool = healthy.isNotEmpty ? healthy : remaining;
    return pool[Random().nextInt(pool.length)];
  }
}
