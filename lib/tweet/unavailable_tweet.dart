import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/urls.dart';

/// Stands for a post X does not show. Its captures can be searched in the Wayback Machine when its author is known
class UnavailableTweetCard extends StatelessWidget {
  /// Why X does not show the post, when it says
  final String? reason;
  final String? screenName;
  final String? id;
  final EdgeInsetsGeometry margin;

  const UnavailableTweetCard(
      {super.key, this.reason, this.screenName, this.id, this.margin = const EdgeInsets.all(12)});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final screenName = this.screenName;
    final id = this.id;

    return StatusCard(
      icon: Icons.hide_source,
      title: l10n.tweet_unavailable,
      details: reason ?? l10n.tweet_unavailable_no_reason,
      margin: margin,
      actions: [
        if (screenName != null && id != null)
          TextButton(
            onPressed: () => openUri(context, waybackSearchUri(screenName, id).toString()),
            child: Text(l10n.search_web_archive),
          ),
      ],
    );
  }
}
