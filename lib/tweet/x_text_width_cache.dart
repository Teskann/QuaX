import 'dart:collection';

import 'package:material_ui/material_ui.dart';

typedef TextWidthMeasurer = double Function(String text, TextStyle style, TextScaler textScaler, TextDirection direction);

double measureTextWidth(String text, TextStyle style, TextScaler textScaler, TextDirection direction) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Remembers the width of single-line texts, so that laying out the same tile again does not measure them again.
/// Least recently used entries are dropped when [capacity] is exceeded.
class TextWidthCache {
  final int capacity;
  final TextWidthMeasurer measure;
  final LinkedHashMap<(String, TextStyle, TextScaler), double> _widths = LinkedHashMap();

  TextWidthCache({this.capacity = 512, this.measure = measureTextWidth});

  int get length => _widths.length;

  double width(String text, TextStyle style, TextScaler textScaler, TextDirection direction) {
    final key = (text, style, textScaler);
    final cached = _widths.remove(key);
    final width = cached ?? measure(text, style, textScaler, direction);
    _widths[key] = width;
    if (_widths.length > capacity) _widths.remove(_widths.keys.first);
    return width;
  }
}
