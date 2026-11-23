import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/feed_chunk.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/utils/urls.dart';

// Temporary, revert this file and its uses: X suspends accounts it finds too active, so feeds load only their first chunk.

const optionUnlimitedFeeds = 'feeds.unlimited';

bool feedLimitLifted(BuildContext context) => PrefService.of(context).get<bool>(optionUnlimitedFeeds) ?? false;

/// The chunks to load, and the warning to show above the feed when some were left out
({List<FeedChunk> chunks, Widget? warning}) limitFeed(List<FeedChunk> allChunks, {required bool lifted}) {
  final chunks = lifted ? allChunks : allChunks.take(1).toList();
  final warning = chunks.length < allChunks.length
      ? FeedLimitWarning(
          loadedSubscriptions: subscriptionCountOf(chunks),
          totalSubscriptions: subscriptionCountOf(allChunks),
        )
      : null;
  return (chunks: chunks, warning: warning);
}

class FeedLimitWarning extends StatelessWidget {
  final int loadedSubscriptions;
  final int totalSubscriptions;

  const FeedLimitWarning({super.key, required this.loadedSubscriptions, required this.totalSubscriptions});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return StatusCard(
      level: StatusLevel.warning,
      icon: Icons.shield_outlined,
      title: l10n.feed_limited_title,
      details: l10n.feed_limited_message(loadedSubscriptions.toString(), totalSubscriptions.toString()),
      actions: [
        TextButton(onPressed: () => _confirmLoadWholeFeed(context), child: Text(l10n.load_the_whole_feed)),
        FilledButton(onPressed: () => openUri(context, discordInviteUrl), child: Text(l10n.discuss_on_discord)),
      ],
    );
  }
}

Future<void> _confirmLoadWholeFeed(BuildContext context) async {
  final l10n = L10n.of(context);
  final accepted = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded),
      title: Text(l10n.load_the_whole_feed_title),
      content: Text(l10n.load_the_whole_feed_warning),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.i_accept_the_risk)),
      ],
    ),
  );
  if (accepted == true && context.mounted) {
    await PrefService.of(context, listen: false).set(optionUnlimitedFeeds, true);
  }
}
