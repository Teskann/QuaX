import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/space/space.dart';
import 'package:quax/space/space_model.dart';
import 'package:quax/space/space_player.dart';
import 'package:quax/space/space_status.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/urls.dart';
import 'package:share_plus/share_plus.dart';

class SpaceScreenArguments {
  final String id;
  final bool autoplay;

  SpaceScreenArguments(this.id, {this.autoplay = false});
}

void openSpace(BuildContext context, String id, {bool autoplay = false}) =>
    Navigator.pushNamed(context, routeSpace, arguments: SpaceScreenArguments(id, autoplay: autoplay));

class SpaceScreen extends StatelessWidget {
  const SpaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as SpaceScreenArguments;

    return Provider(
      create: (_) => SpaceModel(args.id)..load(),
      dispose: (_, SpaceModel model) => model.destroy(),
      child: Builder(
        builder: (context) {
          final model = context.read<SpaceModel>();
          return ScopedBuilder<SpaceModel, Space>.transition(
            store: model,
            onLoading: (_) => Scaffold(
              appBar: _SpaceAppBar(id: args.id),
              body: const Center(child: CircularProgressIndicator()),
            ),
            onError: (_, error) => Scaffold(
              appBar: _SpaceAppBar(id: args.id),
              body: FullPageErrorWidget(
                error: error,
                stackTrace: null,
                prefix: (l10n) => l10n.unable_to_load_the_space,
                onRetry: model.load,
              ),
            ),
            onState: (_, space) => Scaffold(
              appBar: _SpaceAppBar(id: args.id),
              body: _SpaceDetails(space: space, autoplay: args.autoplay),
            ),
          );
        },
      ),
    );
  }
}

class _SpaceAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String id;

  const _SpaceAppBar({required this.id});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final link = '${shareBaseUrlOf(PrefService.of(context))}/i/spaces/$id';
    return AppBar(
      actions: [
        IconButton(
          icon: Icon(Icons.open_in_browser, semanticLabel: l10n.open_in_browser),
          onPressed: () => openInDefaultBrowser('https://x.com/i/spaces/$id'),
        ),
        IconButton(
          icon: Icon(Icons.share, semanticLabel: l10n.share),
          onPressed: () => SharePlus.instance.share(ShareParams(text: link)),
        ),
      ],
    );
  }
}

class _SpaceDetails extends StatelessWidget {
  final Space space;
  final bool autoplay;

  const _SpaceDetails({required this.space, required this.autoplay});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final textTheme = Theme.of(context).textTheme;
    // Not a ListView: it would dispose of the player, and stop it, once scrolled off screen
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 4, 18, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StateChip(space: space),
          Text(space.title, style: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SpaceStatusLine(space: space, color: Theme.of(context).colorScheme.onSurfaceVariant),
          if (space.canPlay) SpacePlayer(space: space, autoplay: autoplay),
          if (space.hosts.isNotEmpty) _ParticipantSection(title: l10n.space_hosts, users: space.hosts),
          if (space.speakers.isNotEmpty) _ParticipantSection(title: l10n.space_speakers, users: space.speakers),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final Space space;

  const _StateChip({required this.space});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final colors = Theme.of(context).colorScheme;
    return switch (space.state) {
      SpaceState.live => _chip(Icons.graphic_eq, l10n.space_live, colors.errorContainer, colors.onErrorContainer),
      SpaceState.scheduled => _chip(
        Icons.schedule,
        l10n.space_not_started,
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      // An ended space says so on its status line, under the title
      SpaceState.ended => const SizedBox.shrink(),
    };
  }

  Widget _chip(IconData icon, String label, Color background, Color foreground) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Chip(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      backgroundColor: background,
      side: BorderSide.none,
    ),
  );
}

class _ParticipantSection extends StatelessWidget {
  final String title;
  final List<SpaceUser> users;

  const _ParticipantSection({required this.title, required this.users});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 22, bottom: 12),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium!.copyWith(color: theme.colorScheme.onSurfaceVariant, letterSpacing: 1),
          ),
        ),
        Wrap(spacing: 6, runSpacing: 14, children: users.map((user) => _Participant(user: user)).toList()),
      ],
    );
  }
}

class _Participant extends StatelessWidget {
  final SpaceUser user;

  const _Participant({required this.user});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.pushNamed(
        context,
        routeProfile,
        arguments: ProfileScreenArguments.fromScreenName(user.screenName, null),
      ),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            UserAvatar(uri: user.avatarUrl, size: 56),
            const SizedBox(height: 6),
            Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodySmall),
            Text(
              '@${user.screenName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall!.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
