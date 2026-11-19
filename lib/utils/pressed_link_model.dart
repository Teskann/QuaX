import 'package:flutter/gestures.dart';
import 'package:flutter_triple/flutter_triple.dart';

/// The link under the finger of the user, known by the recognizer of its span, highlighted so that they see which
/// one they press.
class PressedLinkModel extends Store<({GestureRecognizer? link})> {
  // Why: Store.update() keeps the previous state when given null, so the state is a record that can hold no link
  PressedLinkModel() : super((link: null));

  void press(GestureRecognizer link) => update((link: link));

  /// Clears the highlight of [link] only: the end of a press must not clear another link still pressed.
  void release(GestureRecognizer link) {
    if (identical(state.link, link)) update((link: null));
  }
}
