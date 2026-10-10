import 'package:material_ui/material_ui.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// What the screen learns about the page it shows
typedef XWebPageEvents = ({
  ValueChanged<int> onProgress,
  ValueChanged<Uri> onPageFinished,
  ValueChanged<Uri> onUrlChange,
});

/// The web view of X's pages inside QuaX, behind an interface so that tests need no platform view
abstract class XWebPage {
  Future<void> setUp({required String userAgent, required XWebPageEvents events});

  Future<void> load(Uri uri);

  Widget build();
}

class PlatformXWebPage implements XWebPage {
  final _controller = WebViewController();

  @override
  Future<void> setUp({required String userAgent, required XWebPageEvents events}) async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setUserAgent(userAgent);
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: events.onProgress,
        onPageFinished: (url) => _report(url, events.onPageFinished),
        onUrlChange: (change) => _report(change.url, events.onUrlChange),
      ),
    );
  }

  static void _report(String? url, ValueChanged<Uri> listener) {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri != null) listener(uri);
  }

  @override
  Future<void> load(Uri uri) => _controller.loadRequest(uri);

  @override
  Widget build() => WebViewWidget(controller: _controller);
}
