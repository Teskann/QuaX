import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/space/space.dart';
import 'package:quax/ui/locale_fallback.dart';

String formatSpaceDuration(Duration duration) {
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return duration.inHours > 0 ? '${duration.inHours}:$minutes:$seconds' : '${duration.inMinutes}:$seconds';
}

String _scheduledDate(DateTime? date) =>
    date == null ? '' : DateFormat.MMMEd(formattingLocale()).add_Hm().format(date.toLocal());

String _endedDetails(L10n l10n, Space space) => [
  l10n.space_ended,
  l10n.space_tuned_in(space.tunedInCount),
  if (space.duration != null) formatSpaceDuration(space.duration!),
].join(' · ');

class SpaceStatusLine extends StatelessWidget {
  final Space space;
  final Color? color;

  const SpaceStatusLine({super.key, required this.space, this.color});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final style = Theme.of(context).textTheme.bodyMedium!.copyWith(color: color);
    final (Widget? leading, String text) = switch (space.state) {
      SpaceState.live => (
        const DecoratedBox(
          decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          child: SizedBox.square(dimension: 8),
        ),
        '${l10n.space_live} · ${l10n.space_listening(space.listeningCount)}',
      ),
      SpaceState.ended => (null, _endedDetails(l10n, space)),
      SpaceState.scheduled => (Icon(Icons.schedule, size: 16, color: color), _scheduledDate(space.scheduledStart)),
    };
    return Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 6)],
        Flexible(
          child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
