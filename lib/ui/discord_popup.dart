import 'package:flutter/material.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/utils/urls.dart';

Future<void> checkForDiscord(BuildContext context) async {
  final prefs = PrefService.of(context, listen: false);
  if (prefs.get<bool>(optionDiscordPopupDismissed) ?? false) {
    return;
  }

  await showDialog(
    context: context,
    builder: (context) => const _DiscordInviteDialog(),
  );
}

class _DiscordInviteDialog extends StatefulWidget {
  const _DiscordInviteDialog();

  @override
  State<_DiscordInviteDialog> createState() => _DiscordInviteDialogState();
}

class _DiscordInviteDialogState extends State<_DiscordInviteDialog> {
  bool _dontShowAgain = false;

  void _dismiss() {
    if (_dontShowAgain) {
      PrefService.of(context, listen: false).set(optionDiscordPopupDismissed, true);
    }
    Navigator.of(context).pop();
  }

  Future<void> _join() async {
    await openUri(context, discordInviteUrl);
    if (mounted) {
      _dismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.forum),
      title: Text(L10n.of(context).discord_popup_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.of(context).discord_popup_message),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
            child: Row(
              children: [
                Checkbox(
                  value: _dontShowAgain,
                  onChanged: (value) => setState(() => _dontShowAgain = value ?? false),
                ),
                Flexible(child: Text(L10n.of(context).discord_popup_dont_show_again)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _dismiss,
          child: Text(L10n.of(context).close),
        ),
        TextButton(
          onPressed: _join,
          child: Text(L10n.of(context).discord_popup_join),
        ),
      ],
    );
  }
}
