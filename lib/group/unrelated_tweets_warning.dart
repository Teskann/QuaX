import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/settings/_account.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/urls.dart';

const _unrelatedTweetsIssue = 'https://github.com/Teskann/QuaX/issues/26';

/// Warns that the feed shows posts from people the user does not follow, which logging in with another account fixes
class UnrelatedTweetsWarning extends StatelessWidget {
  const UnrelatedTweetsWarning({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return StatusCard(
      level: StatusLevel.warning,
      icon: Icons.warning_amber_rounded,
      title: l10n.feed_issue_detected,
      details: l10n.feed_contains_unrelated_tweets,
      actions: [
        TextButton(onPressed: () => openUri(context, _unrelatedTweetsIssue), child: Text(l10n.more_info)),
        FilledButton(onPressed: () => openAccountSettings(context), child: Text(l10n.account_settings)),
      ],
    );
  }
}
