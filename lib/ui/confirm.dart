import 'package:material_ui/material_ui.dart';

/// Asks to confirm an action. Returns whether it was confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? content,
  required String cancelLabel,
  required String confirmLabel,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content == null ? null : Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(cancelLabel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(confirmLabel)),
        ],
      ),
    ) ??
    false;
