import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/math_font.dart';

const _boldE = '\u{1D5F2}';
const _acute = '\u0301';
const _style = TextStyle(fontSize: 100, color: Colors.black, fontFamilyFallback: appFontFamilyFallback);

Future<Rect> _ink(String text) async {
  final painter = TextPainter(text: TextSpan(text: text, style: _style), textDirection: TextDirection.ltr)..layout();
  final recorder = ui.PictureRecorder();
  painter.paint(Canvas(recorder), Offset.zero);
  final width = painter.width.ceil();
  final image = await recorder.endRecording().toImage(width, painter.height.ceil());
  final pixels = (await image.toByteData())!;
  final inked = [
    for (var i = 0; i < pixels.lengthInBytes ~/ 4; i++)
      if (pixels.getUint8(i * 4 + 3) > 0) Offset((i % width).toDouble(), (i ~/ width).toDouble())
  ];
  return inked.skip(1).fold<Rect>(Rect.fromPoints(inked.first, inked.first),
      (ink, pixel) => ink.expandToInclude(Rect.fromPoints(pixel, pixel)));
}

void main() {
  setUpAll(() async {
    await (FontLoader(mathFontFamily)..addFont(rootBundle.load('assets/fonts/NotoSansMath-Accents.ttf')))
        .load();
  });

  testWidgets('Should draw the accent of a bold Unicode letter above it', (tester) async {
    late Rect letter;
    late Rect accented;
    await tester.runAsync(() async {
      letter = await _ink(_boldE);
      accented = await _ink('$_boldE$_acute');
    });

    expect(accented.top, lessThan(letter.top),
        reason: 'The accent should be drawn above the letter, not as a box nor left out');
    expect(accented.left, letter.left, reason: 'The accent should not stick out on the left of the letter');
    expect(accented.right, letter.right, reason: 'The accent should not stick out on the right of the letter');
  });
}
