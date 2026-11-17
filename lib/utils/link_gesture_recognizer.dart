import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:quax/utils/pressed_link_model.dart';

/// Reacts to a tap and, when given [onLongPress], to a long press on a link. A text span takes one recognizer only,
/// so it does both. [pressedLink] learns while the link is pressed.
class LinkGestureRecognizer extends TapGestureRecognizer {
  LinkGestureRecognizer({this.pressedLink});

  final PressedLinkModel? pressedLink;
  VoidCallback? onLongPress;

  Timer? _longPressTimer;
  bool _longPressed = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    _longPressed = false;
    _longPressTimer?.cancel();
    // Without its own long press, the link leaves it to the text, which selects words
    if (onLongPress != null) _longPressTimer = Timer(kLongPressTimeout, _handleLongPress);
  }

  void _handleLongPress() {
    _longPressed = true;
    resolve(GestureDisposition.accepted);
    onLongPress?.call();
  }

  @override
  void handleTapDown({required PointerDownEvent down}) {
    pressedLink?.press(this);
    super.handleTapDown(down: down);
  }

  @override
  void handleTapCancel({required PointerDownEvent down, PointerCancelEvent? cancel, required String reason}) {
    pressedLink?.release(this);
    super.handleTapCancel(down: down, cancel: cancel, reason: reason);
  }

  @override
  void handleTapUp({required PointerDownEvent down, required PointerUpEvent up}) {
    // Why: on a quick tap, Flutter only announces the press once the finger is lifted, after it stopped tracking it
    pressedLink?.release(this);
    // A long press already did its job, so lifting the finger is not a tap
    if (!_longPressed) super.handleTapUp(down: down, up: up);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _longPressTimer?.cancel();
    pressedLink?.release(this);
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    super.dispose();
  }
}
