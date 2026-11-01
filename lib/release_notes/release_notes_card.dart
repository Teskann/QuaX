import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/release_notes/release_notes.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/ui/link_style.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/urls.dart';

// Issue numbers and GitHub accounts, like #311 or @quax-bot
final _githubReference = RegExp(r'#(\d+)|@([\w-]+)(\[bot\])?');

String _githubLink(Match match) => match[1] != null
    ? '$issuesUrl/${match[1]}'
    : match[3] == null
        ? 'https://github.com/${match[2]}'
        : 'https://github.com/apps/${match[2]}';

const _notesBeforeShowMore = 5;

/// Shows the release notes at the top of the feeds.
class ReleaseNotesCard extends StatelessWidget {
  final List<ReleaseNote> releases;
  final VoidCallback onHide;

  const ReleaseNotesCard({super.key, required this.releases, required this.onHide});

  @override
  Widget build(BuildContext context) {
    final fullText = PrefService.of(context).get<bool>(alwaysShowFullTweetContents) ?? false;
    return Card(
      color: tweetCardColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: const UserAvatar(uri: quaxIcon),
            title: const _Author(),
            trailing: IconButton(
                icon: const Icon(Icons.close), tooltip: L10n.of(context).hide_release_notes, onPressed: onHide),
          ),
          ...releases.map((release) => _ReleaseSection(release: release, fold: !fullText)),
        ],
      ),
    );
  }
}

class _ReleaseSection extends StatefulWidget {
  final ReleaseNote release;
  final bool fold;

  const _ReleaseSection({required this.release, required this.fold});

  @override
  State<_ReleaseSection> createState() => _ReleaseSectionState();
}

class _ReleaseSectionState extends State<_ReleaseSection> {
  bool _expanded = false;

  bool get _folded => widget.fold && !_expanded && widget.release.notes.length > _notesBeforeShowMore;

  @override
  Widget build(BuildContext context) {
    final notes = _folded ? widget.release.notes.take(_notesBeforeShowMore) : widget.release.notes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.of(context).release_notes_version(widget.release.version),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...notes.map((note) => _Note(note)),
          if (_folded)
            GestureDetector(
              onTap: () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(L10n.of(context).clickToShowMore,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String note;

  const _Note(this.note);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•   '),
            Expanded(child: Text.rich(TextSpan(children: _linked(context)))),
          ],
        ),
      );

  List<InlineSpan> _linked(BuildContext context) {
    final spans = <InlineSpan>[];
    note.splitMapJoin(_githubReference, onMatch: (match) {
      spans.add(TextSpan(
          text: match[0],
          style: linkStyle(context),
          recognizer: TapGestureRecognizer()..onTap = () => openUri(context, _githubLink(match))));
      return '';
    }, onNonMatch: (plain) {
      spans.add(TextSpan(text: plain));
      return '';
    });
    return spans;
  }
}

class _Author extends StatelessWidget {
  const _Author();

  @override
  Widget build(BuildContext context) => Row(children: [
        const Flexible(
            child: Text('QuaX Release Notes',
                overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500))),
        const SizedBox(width: 4),
        Icon(Icons.verified, size: 18, color: Theme.of(context).colorScheme.primary),
      ]);
}
