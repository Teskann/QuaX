import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/settings/_tweet_actions.dart';
import 'package:quax/ui/list_sheet.dart';

class MoreActionsEntry {
  final IconData icon;
  final String label;
  final String? count;
  final VoidCallback? onTap;

  const MoreActionsEntry({required this.icon, required this.label, this.count, this.onTap});
}

Future<void> showMoreActionsSheet(BuildContext context, List<MoreActionsEntry> entries) {
  return showListSheet(
    context,
    (sheetContext) => ListSheet(
      icon: Icons.more_vert,
      title: L10n.of(sheetContext).more,
      footer: ListTile(
        contentPadding: listSheetTilePadding,
        leading: const Icon(Icons.tune),
        title: Text(L10n.of(sheetContext).customize_action_bar),
        onTap: () {
          Navigator.pop(sheetContext);
          Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsTweetActionsFragment()));
        },
      ),
      children: entries.map((e) => _EntryTile(entry: e)).toList(),
    ),
  );
}

class _EntryTile extends StatelessWidget {
  final MoreActionsEntry entry;

  const _EntryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final onTap = entry.onTap;

    return ListTile(
      contentPadding: listSheetTilePadding,
      leading: Icon(entry.icon),
      title: Text(entry.label),
      trailing: entry.count == null ? null : Text(entry.count!),
      onTap: onTap == null
          ? null
          : () {
              Navigator.pop(context);
              onTap();
            },
    );
  }
}
