import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/space/space.dart';
import 'package:quax/space/space_model.dart';
import 'package:quax/space/space_screen.dart';
import 'package:quax/space/space_status.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';

/// The card of a tweet that links to a space: X only sends its id, so the space is loaded here.
class SpaceCard extends StatelessWidget {
  final String id;

  const SpaceCard({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Provider(
      // A card reused for another post should load that post's space
      key: ValueKey(id),
      create: (_) => SpaceModel(id)..load(),
      dispose: (_, SpaceModel model) => model.destroy(),
      child: Builder(
        builder: (context) {
          final model = context.read<SpaceModel>();
          return ScopedBuilder<SpaceModel, Space>(
            store: model,
            onLoading: (_) => const _SpaceCardFrame(
              child: SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
            ),
            onError: (context, error) => ErrorCard(
              error: error,
              stackTrace: null,
              prefix: (l10n) => l10n.unable_to_load_the_space,
              onRetry: model.load,
            ),
            onState: (_, space) => _SpaceCardFrame(
              space: space,
              child: _SpaceCardContent(space: space),
            ),
          );
        },
      ),
    );
  }
}

class _SpaceCardFrame extends StatelessWidget {
  final Space? space;
  final Widget child;

  const _SpaceCardFrame({this.space, required this.child});

  @override
  Widget build(BuildContext context) {
    final space = this.space;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: double.infinity,
      child: Material(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: space == null ? null : () => openSpace(context, space.id), child: child),
      ),
    );
  }
}

class _SpaceCardContent extends StatelessWidget {
  final Space space;

  const _SpaceCardContent({required this.space});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onPrimaryContainer;
    final host = space.hosts.firstOrNull;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (host != null) ...[_HostRow(host: host, color: color), const SizedBox(height: 10)],
          Text(
            space.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium!.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          SpaceStatusLine(space: space, color: color),
          const SizedBox(height: 12),
          SpaceListenButton(space: space),
        ],
      ),
    );
  }
}

class _HostRow extends StatelessWidget {
  final SpaceUser host;
  final Color color;

  const _HostRow({required this.host, required this.color});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        UserAvatar(uri: host.avatarUrl, size: 24),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            host.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium!.copyWith(color: color),
          ),
        ),
        const SizedBox(width: 8),
        DecoratedBox(
          decoration: BoxDecoration(color: color.withAlpha(40), borderRadius: BorderRadius.circular(6)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            child: Text(L10n.of(context).space_host, style: textTheme.labelSmall!.copyWith(color: color)),
          ),
        ),
      ],
    );
  }
}

/// Says whether the space can be listened to, and opens it when it can.
class SpaceListenButton extends StatelessWidget {
  final Space space;

  const SpaceListenButton({super.key, required this.space});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final colors = Theme.of(context).colorScheme;
    final (IconData icon, String label) = switch (space.state) {
      SpaceState.live => (Icons.graphic_eq, l10n.space_listen_live),
      SpaceState.ended when space.canPlay => (Icons.play_arrow, l10n.space_play_recording),
      SpaceState.ended => (Icons.mic_off, l10n.space_no_recording),
      SpaceState.scheduled => (Icons.event, l10n.space_not_started),
    };
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.onPrimaryContainer,
          foregroundColor: colors.primaryContainer,
        ),
        onPressed: space.canPlay ? () => openSpace(context, space.id, autoplay: true) : null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
