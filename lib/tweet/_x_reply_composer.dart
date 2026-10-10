import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/home/_x_account.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/utils/urls.dart';
import 'package:quax/utils/x_intents.dart';

/// The bar pinned at the bottom of an opened post in the X design, where a reply is typed. QuaX cannot post, so
/// "Reply" hands the text over to X through its web intent.
class XReplyComposer extends StatefulWidget {
  final String tweetId;

  /// Whether the field takes the focus as soon as the post opens
  final bool autofocus;
  final UriOpener opener;

  const XReplyComposer({super.key, required this.tweetId, this.autofocus = false, this.opener = openUri});

  @override
  State<XReplyComposer> createState() => _XReplyComposerState();
}

class _XReplyComposerState extends State<XReplyComposer> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _reply() async {
    final url = xReplyIntentUrl(widget.tweetId, _text.text.trim());
    _text.clear();
    await widget.opener(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    final l10n = L10n.of(context);

    return Material(
      color: colors.background,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: colors.divider))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const XAccountAvatar(size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _text,
                    autofocus: widget.autofocus,
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(fontSize: 16, color: colors.primaryText),
                    decoration: InputDecoration(
                      hintText: l10n.x_post_your_reply,
                      hintStyle: TextStyle(fontSize: 16, color: colors.secondaryText),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _reply,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: Text(l10n.x_reply, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
