import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/community/community.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/locale_fallback.dart';

class CommunityAbout extends StatelessWidget {
  final Community community;

  const CommunityAbout({super.key, required this.community});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final text = theme.textTheme.bodyMedium?.copyWith(letterSpacing: 0);
    final description = community.description;
    final topic = community.topic;
    final createdAt = community.createdAt;

    return ListTileTheme(
      data: ListTileThemeData(visualDensity: VisualDensity.compact, titleTextStyle: text),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (description != null && description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SelectableText(description, style: text),
            ),
          if (topic != null) ListTile(leading: const Icon(Icons.label_outline), title: Text(topic)),
          if (createdAt != null)
            ListTile(
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(l10n.community_created(DateFormat.yMMMM(formattingLocale()).format(createdAt))),
            ),
          if (community.rules.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.community_rules, style: theme.textTheme.titleSmall),
            ),
            ...community.rules.indexed.map(
              (rule) => ListTile(
                leading: CircleAvatar(radius: 12, child: Text('${rule.$1 + 1}', style: theme.textTheme.labelSmall)),
                title: Text(rule.$2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
