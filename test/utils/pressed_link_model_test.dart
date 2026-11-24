import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/pressed_link_model.dart';

void main() {
  test('Should keep a link highlighted when the press of another link ends', () {
    final pressedLink = PressedLinkModel();
    final first = TapGestureRecognizer();
    final second = TapGestureRecognizer();

    pressedLink.press(second);
    pressedLink.release(first);

    expect(pressedLink.state.link, same(second), reason: 'Lifting a finger from a link should not clear another one');

    pressedLink.release(second);

    expect(pressedLink.state.link, isNull, reason: 'Lifting the finger from the highlighted link should clear it');
  });
}
