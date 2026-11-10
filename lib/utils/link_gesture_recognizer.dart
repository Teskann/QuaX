import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

/// Reacts to a tap and to a long press on a link. A text span takes one recognizer only, so it does both.
class LinkGestureRecognizer extends TapGestureRecognizer {
  VoidCallback? onLongPress;

  Timer? _longPressTimer;
  bool _longPressed = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _longPressed = false;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(kLongPressTimeout, _handleLongPress);
  }

  void _handleLongPress() {
    _longPressed = true;
    resolve(GestureDisposition.accepted);
    onLongPress?.call();
  }

  @override
  void handleTapUp({required PointerDownEvent down, required PointerUpEvent up}) {
    // A long press already did its job, so lifting the finger is not a tap
    if (!_longPressed) super.handleTapUp(down: down, up: up);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _longPressTimer?.cancel();
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
}
