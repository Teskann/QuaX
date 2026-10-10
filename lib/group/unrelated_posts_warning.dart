import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/urls.dart';

const unrelatedPostsIssueUri = 'https://github.com/Teskann/QuaX/issues/26';

typedef UriOpener = Future<void> Function(BuildContext context, String uri);

/// Warns that X returned posts from people the feed does not follow, a known issue on its side. [onHide] is called
/// once the user asked not to be warned again
class UnrelatedPostsWarningCard extends StatelessWidget {
  final VoidCallback onHide;
  final UriOpener open;

  const UnrelatedPostsWarningCard({super.key, required this.onHide, this.open = openUri});

  void _dontShowAgain(BuildContext context) {
    PrefService.of(context).set(optionDisableWarningsForUnrelatedPostsInFeed, true);
    onHide();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return StatusCard(
      level: StatusLevel.warning,
      title: l10n.feed_issue_detected,
      details: l10n.feed_contains_unrelated_tweets,
      actions: [
        TextButton(onPressed: () => _dontShowAgain(context), child: Text(l10n.dont_show_again)),
        FilledButton(onPressed: () => open(context, unrelatedPostsIssueUri), child: Text(l10n.more_info)),
      ],
    );
  }
}
