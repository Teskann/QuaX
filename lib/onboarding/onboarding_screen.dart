import 'package:animations/animations.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/client/login_webview.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/client/client_regular_account.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/onboarding/_other_account_step.dart';
import 'package:quax/onboarding/_steps.dart';
import 'package:quax/onboarding/_subscriptions_step.dart';
import 'package:quax/onboarding/onboarding_model.dart';
import 'package:quax/settings/_data.dart' as data;
import 'package:quax/subscriptions/importer_of.dart';
import 'package:quax/subscriptions/subscription_importer.dart';
import 'package:quax/utils/urls.dart';

/// What the onboarding does outside of itself, replaced in tests.
class OnboardingActions {
  final Future<bool> Function(BuildContext context) importBackup;
  final Future<List<Account>> Function() accounts;
  final Future<Account?> Function(BuildContext context) logIn;
  final Future<void> Function(Account account) logOut;
  final Future<void> Function(BuildContext context) joinDiscord;
  final SubscriptionImporter Function(BuildContext context) importer;

  const OnboardingActions(
      {required this.importBackup,
      required this.accounts,
      required this.logIn,
      required this.logOut,
      required this.joinDiscord,
      required this.importer});

  static final app = OnboardingActions(
    importBackup: data.importBackup,
    accounts: getAccounts,
    logIn: (context) => Navigator.push<Account>(
        context, MaterialPageRoute(builder: (_) => const TwitterLoginWebview(guided: true))),
    logOut: (account) => XRegularAccount().deleteAccount(account.id),
    joinDiscord: (context) => openUri(context, discordInviteUrl),
    importer: subscriptionImporterOf,
  );
}

/// Welcomes a newcomer on the first launch: restores a backup, or sets the theme, the account and the
/// subscriptions up one step at a time.
class OnboardingWizard extends StatefulWidget {
  final OnboardingActions? actions;

  const OnboardingWizard({super.key, this.actions});

  @override
  State<OnboardingWizard> createState() => _OnboardingWizardState();
}

class _OnboardingWizardState extends State<OnboardingWizard> {
  final _model = OnboardingModel();
  late final _actions = widget.actions ?? OnboardingActions.app;
  late final _importModel = SubscriptionImportModel(_actions.importer(context));
  late final _otherAccountImportModel = SubscriptionImportModel(_actions.importer(context));

  @override
  void initState() {
    super.initState();
    _actions.accounts().then(_model.restoreAccount);
  }

  @override
  void dispose() {
    _model.destroy();
    _importModel.destroy();
    _otherAccountImportModel.destroy();
    super.dispose();
  }

  void _finish() {
    final prefs = PrefService.of(context, listen: false);
    prefs.set(optionOnboardingDone, true);
    // The community step already offered the Discord, so it should not pop up later on
    prefs.set(optionDiscordPopupDismissed, true);
    Navigator.pushReplacementNamed(context, routeHome);
  }

  Duration _transitionDuration(BuildContext context) =>
      PrefService.of(context, listen: false).get<bool>(optionDisableAnimations) ?? false
          ? Duration.zero
          : const Duration(milliseconds: 300);

  Widget _step(OnboardingState state) => switch (state.step) {
        OnboardingStep.welcome => WelcomeStep(model: _model, importBackup: () => _actions.importBackup(context)),
        OnboardingStep.theme => ThemeStep(model: _model),
        OnboardingStep.login => LoginStep(model: _model, logIn: () => _actions.logIn(context), logOut: _actions.logOut),
        OnboardingStep.noAccount => NoAccountStep(model: _model, logIn: () => _actions.logIn(context)),
        OnboardingStep.subscriptions =>
          SubscriptionsStep(model: _model, importModel: _importModel, screenName: state.screenName),
        OnboardingStep.otherAccount => OtherAccountStep(model: _model, importModel: _otherAccountImportModel),
        OnboardingStep.community =>
          CommunityStep(model: _model, joinDiscord: () => _actions.joinDiscord(context), onFinish: _finish),
      };

  @override
  Widget build(BuildContext context) {
    return TripleBuilder<OnboardingModel, OnboardingState>(
      store: _model,
      builder: (context, triple) => PopScope(
        canPop: !triple.state.canGoBack,
        onPopInvokedWithResult: (didPop, _) => didPop ? null : _model.back(),
        child: PageTransitionSwitcher(
          duration: _transitionDuration(context),
          reverse: triple.state.wentBack,
          transitionBuilder: (child, animation, secondaryAnimation) => SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.horizontal,
            child: child,
          ),
          child: KeyedSubtree(key: ValueKey(triple.state.step), child: _step(triple.state)),
        ),
      ),
    );
  }
}
