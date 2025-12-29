import 'package:flutter/material.dart';
import 'package:quax/generated/l10n.dart';

class ExpandableTweetText extends StatefulWidget {
  final List<InlineSpan> textSpans;
  final VoidCallback? onTap;
  final int? maxLines;

  const ExpandableTweetText({
    super.key,
    required this.textSpans,
    this.onTap,
    this.maxLines = 8,
  });

  @override
  ExpandableTweetTextState createState() => ExpandableTweetTextState();
}

class ExpandableTweetTextState extends State<ExpandableTweetText> {
  bool _isExpanded = false;

  bool _textIsTruncated() {
    if (!mounted) return false;

    if (widget.maxLines == null) return false;

    final painter = TextPainter(
      text: TextSpan(children: widget.textSpans),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.of(context).textScaler,
    );

    painter.layout(maxWidth: MediaQuery.of(context).size.width);
    final res = painter.computeLineMetrics().length > widget.maxLines!;
    painter.dispose();

    return res;
  }

  @override
  Widget build(BuildContext context) {
    final textIsTruncated = _textIsTruncated();
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isExpanded && textIsTruncated)
              ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 0.8, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Text.rich(
                    TextSpan(children: widget.textSpans),
                    maxLines: widget.maxLines,
                    overflow: TextOverflow.clip,
                    style: DefaultTextStyle.of(context).style,
                  ),
                ),
              )
            else
              GestureDetector(
                onTap: widget.onTap,
                child: Text.rich(
                  TextSpan(children: widget.textSpans),
                  maxLines: _isExpanded || !textIsTruncated ? null : widget.maxLines,
                  overflow: _isExpanded || !textIsTruncated ? TextOverflow.visible : TextOverflow.fade,
                ),
              ),
            if (!_isExpanded && textIsTruncated)
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
        );
      },
    );
  }
}
