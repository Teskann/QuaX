import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_sheet.dart';
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
    showXSheet(
      context,
      (sheetContext) => XSheet(children: [
        XSheetRow(
            icon: XIcons.repost,
            label: L10n.of(sheetContext).x_repost,
            onTap: () => _open(sheetContext, opener, xRepostIntentUrl(tweetId))),
        XSheetRow(
            icon: XIcons.pencilSimpleLine,
            label: L10n.of(sheetContext).x_quote,
            onTap: () => _open(sheetContext, opener, xQuoteIntentUrl(screenName, tweetId))),
      ]),
    );

Future<void> _open(BuildContext sheetContext, UriOpener opener, String url) async {
  final navigator = Navigator.of(sheetContext);
  navigator.pop();
  await opener(navigator.context, url);
}
