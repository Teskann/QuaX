import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/subscriptions/subscription_importer.dart';

enum OnboardingStep { welcome, theme, login, noAccount, subscriptions, otherAccount, community }

class OnboardingState {
  /// Steps the user went through, the current one last, so that going back retraces their path.
  final List<OnboardingStep> path;

  /// The account QuaX uses, logged in during the onboarding or saved before it.
  final Account? account;

  /// Whether the user got to this step by going back.
  final bool wentBack;

  /// Whether the welcome drawing played once already, so that it shows at once when it is built again, such as after
  /// going back or turning the screen.
  final bool welcomePlayed;

  const OnboardingState({required this.path, this.account, this.wentBack = false, this.welcomePlayed = false});

  OnboardingStep get step => path.last;

  bool get canGoBack => path.length > 1;

  String? get screenName => account?.screenName;

  OnboardingState _copy({List<OnboardingStep>? path, Account? account, bool? wentBack, bool? welcomePlayed}) =>
      OnboardingState(
          path: path ?? this.path,
          account: account ?? this.account,
          wentBack: wentBack ?? this.wentBack,
          welcomePlayed: welcomePlayed ?? this.welcomePlayed);

  OnboardingState goTo(OnboardingStep step, {Account? account}) =>
      _copy(path: [...path, step], account: account, wentBack: false);

  OnboardingState back() => canGoBack ? _copy(path: path.sublist(0, path.length - 1), wentBack: true) : this;

  OnboardingState playedWelcome() => _copy(welcomePlayed: true);

  OnboardingState withAccount(Account account) => _copy(account: account);

  OnboardingState loggedOut() =>
      OnboardingState(path: path, wentBack: wentBack, welcomePlayed: welcomePlayed);
}

class OnboardingModel extends Store<OnboardingState> {
  OnboardingModel() : super(const OnboardingState(path: [OnboardingStep.welcome]));

  void goTo(OnboardingStep step) => update(state.goTo(step));

  void back() => update(state.back());

  void playedWelcome() => update(state.playedWelcome());

  /// Takes the first of the [accounts] already saved, such as one logged in before the app was closed, so that the
  /// user is not asked to log in again.
  void restoreAccount(List<Account> accounts) {
    if (accounts.isNotEmpty && state.account == null) {
      update(state.withAccount(accounts.first));
    }
  }

  /// Restores a backup with [pick], which tells whether one was picked. A restored backup holds the settings,
  /// accounts and subscriptions, so only the community step is left.
  Future<void> importBackup(Future<bool> Function() pick) => execute(() async {
        final imported = await pick();
        return imported ? state.goTo(OnboardingStep.community) : state;
      });

  /// Logs in with [logIn], which gives the account, or null when the user gave up.
  Future<void> logIn(Future<Account?> Function() logIn) => execute(() async {
        final account = await logIn();
        return account == null ? state : state.goTo(OnboardingStep.subscriptions, account: account);
      });

  /// Removes the account from QuaX, so that the user can log in with another one.
  Future<void> logOut(Future<void> Function(Account account) logOut) => execute(() async {
        final account = state.account;
        if (account != null) {
          await logOut(account);
        }
        return state.loggedOut();
      });
}

sealed class SubscriptionImportProgress {
  const SubscriptionImportProgress();
}

class ImportNotStarted extends SubscriptionImportProgress {
  const ImportNotStarted();
}

/// The account follows more accounts than QuaX can load without being rate limited, so the user picks how many.
class ImportTooLarge extends SubscriptionImportProgress {
  final String screenName;
  final int count;
  final int limit;

  const ImportTooLarge(this.screenName, this.count, this.limit);
}

class Importing extends SubscriptionImportProgress {
  final int imported;

  const Importing(this.imported);
}

class ImportFinished extends SubscriptionImportProgress {
  final int imported;

  /// Accounts still to be added, a few at a time
  final int queued;

  const ImportFinished(this.imported, {this.queued = 0});
}

class SubscriptionImportModel extends Store<SubscriptionImportProgress> {
  final SubscriptionImporter importer;

  SubscriptionImportModel(this.importer) : super(const ImportNotStarted());

  /// Imports everything [screenName] follows, unless it is too much and the user has to choose first.
  Future<void> prepare(String screenName) async {
    setLoading(true);
    try {
      final size = await importer.size(screenName);
      if (size.exceedsLimit) {
        update(ImportTooLarge(screenName, size.count!, size.limit));
        return;
      }
      await start(screenName, size.count ?? 1 << 31);
    } catch (e) {
      setError(e);
    }
  }

  Future<void> start(String screenName, int maxCount) async {
    update(const Importing(0));
    try {
      var last = const ImportProgress(collected: 0);
      await for (final progress in importer.import(screenName, maxCount)) {
        last = progress;
        update(Importing(progress.collected));
      }
      update(ImportFinished(last.imported, queued: last.queued));
    } catch (e) {
      setError(e);
    }
  }

  void reset() => update(const ImportNotStarted(), force: true);
}
