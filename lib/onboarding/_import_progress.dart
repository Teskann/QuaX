import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/onboarding/onboarding_model.dart';
import 'package:quax/ui/errors.dart';

/// Whether the import is fetching the size of the account or importing it
bool importRunning(Triple<SubscriptionImportProgress> triple) =>
    triple.error == null && (triple.isLoading || triple.state is Importing);

/// What an import shows once started: how many accounts to import when there are too many, its progress, its end or
/// its error. Null before it starts.
List<Widget>? importProgress(
    BuildContext context, Triple<SubscriptionImportProgress> triple, SubscriptionImportModel importModel) {
  final l10n = L10n.of(context);
  if (triple.error != null) {
    return [
      ErrorCard(
          error: triple.error, stackTrace: null, prefix: (l10n) => l10n.unable_to_import, onRetry: importModel.reset),
    ];
  }
  return switch (triple.state) {
    ImportNotStarted() => triple.isLoading ? const [] : null,
    ImportTooLarge progress => _tooLarge(l10n, progress, importModel),
    Importing(imported: final imported) =>
      [_status(context, Icons.downloading, l10n.imported_snapshot_data_users_so_far(imported.toString()))],
    ImportFinished(imported: final imported, queued: final queued) => [
        _status(context, Icons.check_circle, l10n.subscriptions_imported(imported)),
        if (queued > 0) _status(context, Icons.schedule, l10n.importing_more_subscriptions(queued, smartImportBatch)),
      ],
  };
}

List<Widget> _tooLarge(L10n l10n, ImportTooLarge progress, SubscriptionImportModel importModel) => [
      Text(l10n.import_too_many_subscriptions_warning(progress.count.toString(), progress.limit.toString())),
      const SizedBox(height: 16),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
        FilledButton(
            onPressed: () => importModel.start(progress.screenName, progress.limit),
            child: Text(l10n.import_count_subscriptions(progress.limit))),
        FilledButton.tonal(
            onPressed: () => importModel.start(progress.screenName, progress.count),
            child: Text(l10n.import_count_subscriptions(progress.count))),
        TextButton(onPressed: importModel.reset, child: Text(l10n.cancel)),
      ]),
    ];

Widget _status(BuildContext context, IconData icon, String text) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
      title: Text(text),
    );
