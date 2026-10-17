import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const _android13 = 33;

// Android 13 and later show their own preview of what was copied
Future<bool> _systemConfirmsCopies() async {
  try {
    final sdk = await const MethodChannel('browser_resolver').invokeMethod<int>('getSdkInt');
    return (sdk ?? 0) >= _android13;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}

Future<void> copyToClipboard(BuildContext context, String text, String confirmation) async {
  final messenger = ScaffoldMessenger.of(context);
  await Clipboard.setData(ClipboardData(text: text));
  if (!await _systemConfirmsCopies()) {
    messenger.showSnackBar(SnackBar(content: Text(confirmation)));
  }
}
