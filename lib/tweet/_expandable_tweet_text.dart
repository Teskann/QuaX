import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';

class ExpandableTweetText extends StatefulWidget {
  final List<InlineSpan> textSpans;
  final VoidCallback? onTap;
  final int? maxLines;

  /// Whether the text can be selected. Feed tiles turn it off, as a selectable text costs much more to build
  final bool selectable;

  /// The color the text fades into when truncated, the one of the surface behind it
  final Color? fadeColor;

  const ExpandableTweetText({
    super.key,
    required this.textSpans,
    this.onTap,
    this.maxLines = 8,
    this.selectable = true,
    this.fadeColor,
  });

  @override
  ExpandableTweetTextState createState() => ExpandableTweetTextState();
}

typedef _TruncationKey = (String, TextStyle, TextScaler, double, int);

/// Remembers which texts overflow their maximum lines, so laying them out again is only done when something changed
class TruncationCache {
  static const _capacity = 256;
  static final Map<_TruncationKey, bool> _results = {};

  /// How many times a text was really measured, for tests to check that the cache is hit
  @visibleForTesting
  static int measureCount = 0;

  @visibleForTesting
  static void clear() {
    _results.clear();
    measureCount = 0;
  }

  static bool isTruncated(List<InlineSpan> spans, TextStyle style, TextScaler textScaler, double maxWidth, int maxLines) {
    final root = TextSpan(style: style, children: spans);
    final key = (root.toPlainText(), style, textScaler, maxWidth, maxLines);
    final cached = _results.remove(key);
    final result = cached ?? _measure(root, textScaler, maxWidth, maxLines);
    _results[key] = result;
    if (_results.length > _capacity) _results.remove(_results.keys.first);
    return result;
  }

  static bool _measure(TextSpan root, TextScaler textScaler, double maxWidth, int maxLines) {
    measureCount++;
    final painter = TextPainter(text: root, textDirection: TextDirection.ltr, textScaler: textScaler);
    painter.layout(maxWidth: maxWidth);
    final res = painter.computeLineMetrics().length > maxLines;
    painter.dispose();
    return res;
  }
}

class ExpandableTweetTextState extends State<ExpandableTweetText> {
  bool _isExpanded = false;

  bool _textIsTruncated(double maxWidth) {
    if (!mounted) return false;

    final maxLines = widget.maxLines;
    if (maxLines == null) return false;

    return TruncationCache.isTruncated(
        widget.textSpans, DefaultTextStyle.of(context).style, MediaQuery.textScalerOf(context), maxWidth, maxLines);
  }

  Widget _buildText(int? maxLines) {
    final text = TextSpan(children: widget.textSpans);
    if (widget.selectable) {
      return SelectableText.rich(
        text,
        scrollPhysics: const NeverScrollableScrollPhysics(),
        maxLines: maxLines,
        onTap: widget.onTap,
      );
    }
    return GestureDetector(onTap: widget.onTap, child: Text.rich(text, maxLines: maxLines));
  }

  Widget _withFade(Widget text) {
    final color = widget.fadeColor ?? Theme.of(context).cardColor;
    final transparent = color.withAlpha(0);
    return Stack(
      children: [
        text,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [transparent, transparent, color],
                  stops: const [0.0, 0.8, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textIsTruncated = _textIsTruncated(constraints.maxWidth);
        final collapsed = !_isExpanded && textIsTruncated;
        return AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (collapsed) _withFade(_buildText(widget.maxLines)) else _buildText(null),
              if (collapsed)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isExpanded = true;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, left: 2),
                      child: Text(
                        L10n.of(context).clickToShowMore,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
