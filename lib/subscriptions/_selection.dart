import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/add_to_groups_sheet.dart';
import 'package:quax/subscriptions/subscription_kind.dart';
import 'package:quax/subscriptions/users_model.dart';

class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Subscription> selected;
  final VoidCallback onClear;

  const SelectionAppBar({super.key, required this.selected, required this.onClear});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final colors = Theme.of(context).colorScheme;
    final hideable = selected.where((s) => SubscriptionKind.of(s).canHideFromMainFeed).toList();
    final allHiddenFromFeed = hideable.isNotEmpty && hideable.every((s) => !s.inFeed);
    return AppBar(
      backgroundColor: colors.secondaryContainer,
      foregroundColor: colors.onSecondaryContainer,
      leading: IconButton(icon: const Icon(Icons.close), tooltip: l10n.close, onPressed: onClear),
      title: Text(l10n.n_selected(selected.length)),
      actions: [
        IconButton(
          icon: const Icon(Icons.create_new_folder_outlined),
          tooltip: l10n.add_to_groups,
          onPressed: () => showGroupsSheet(context, selected, onDone: onClear),
        ),
        if (hideable.isNotEmpty)
          IconButton(
            icon: Icon(allHiddenFromFeed ? Icons.visibility : Icons.visibility_off_outlined),
            tooltip: allHiddenFromFeed ? l10n.show_in_main_feed : l10n.hide_from_main_feed,
            onPressed: () => context.read<SubscriptionsModel>().setShownInMainFeed(hideable, shown: allHiddenFromFeed),
          ),
        IconButton(
          icon: const Icon(Icons.person_remove_outlined),
          tooltip: l10n.unsubscribe,
          onPressed: () => _unsubscribe(context),
        ),
      ],
    );
  }

  Future<void> _unsubscribe(BuildContext context) async {
    final l10n = L10n.of(context);
    final model = context.read<SubscriptionsModel>();
    final messenger = ScaffoldMessenger.of(context);
    // Cleared first, so that a second tap can't unsubscribe again
    onClear();
    final removed = await model.unsubscribe(selected);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.n_subscriptions_removed(removed.subscriptions.length)),
        action: SnackBarAction(label: l10n.undo, onPressed: () => model.resubscribe(removed)),
      ),
    );
  }
}
