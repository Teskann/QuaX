import 'package:material_ui/material_ui.dart';

/// Puts the newest tweet back at the top of the list before scrolling up.
class FeedScrollController extends ScrollController {
  Future<void> Function()? _beforeScrollToTop;

  void register(Future<void> Function() beforeScrollToTop) {
    _beforeScrollToTop = beforeScrollToTop;
  }

  void unregister(Future<void> Function() beforeScrollToTop) {
    if (identical(_beforeScrollToTop, beforeScrollToTop)) {
      _beforeScrollToTop = null;
    }
  }

  Future<void> scrollToTop({required bool animate}) async {
    await _beforeScrollToTop?.call();
    if (!hasClients) return;
    if (!animate) {
      jumpTo(0);
      return;
    }
    await animateTo(0, duration: const Duration(seconds: 1), curve: Curves.easeInOut);
  }
}
