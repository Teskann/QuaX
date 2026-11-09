import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/utils/urls.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a link to a page of X, such as `/i/lists/1`. The link uses the domain chosen in the settings.
class ShareLinkButton extends StatelessWidget {
  final String path;

  const ShareLinkButton({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final link = '${shareBaseUrlOf(PrefService.of(context))}$path';
    return IconButton(
      icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary, semanticLabel: L10n.of(context).share),
      onPressed: () => SharePlus.instance.share(ShareParams(text: link)),
    );
  }
}
