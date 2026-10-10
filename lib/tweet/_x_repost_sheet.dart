import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/utils/urls.dart';
import 'package:quax/utils/x_intents.dart';

/// The sheet of the repost button in the X design: repost or quote the post. QuaX cannot post, so both hand over to
/// X through its web intents.
Future<void> showXRepostSheet(
  BuildContext context, {
  required String tweetId,
  required String screenName,
  UriOpener opener = openUri,
}) =>
    showModalBottomSheet(
      context: context,
      backgroundColor: XStyleColors.of(context).background,
      builder: (sheetContext) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _XRepostOption(
              icon: XIcons.repost,
              label: L10n.of(sheetContext).x_repost,
              onTap: () => _open(sheetContext, opener, xRepostIntentUrl(tweetId))),
          _XRepostOption(
              icon: XIcons.pencilSimpleLine,
              label: L10n.of(sheetContext).x_quote,
              onTap: () => _open(sheetContext, opener, xQuoteIntentUrl(screenName, tweetId))),
        ]),
      ),
    );

Future<void> _open(BuildContext sheetContext, UriOpener opener, String url) async {
  final navigator = Navigator.of(sheetContext);
  navigator.pop();
  await opener(navigator.context, url);
}

class _XRepostOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _XRepostOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Icon(icon, size: 24, color: colors.primaryText),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.primaryText)),
          ]),
        ),
      ),
    );
  }
}
