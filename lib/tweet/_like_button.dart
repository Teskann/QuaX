import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:quax/tweet/tweet.dart';

/// The footer "like" heart, with the full X-style burst: a ring expands out of
/// the heart, then a spray of coloured confetti bursts and fades, while the
/// heart itself pops with an elastic bounce. Unliking just switches the glyph.
class LikeButton extends StatefulWidget {
  final bool isLiked;
  final String label;
  final Color? color;
  final VoidCallback onPressed;

  const LikeButton(
      {super.key, required this.isLiked, required this.label, required this.color, required this.onPressed});

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> with SingleTickerProviderStateMixin {
  static const double _iconSize = 20;
  static const double _burstSize = 46;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)), weight: 65),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isLiked) {
      _controller.forward(from: 0);
    }
    widget.onPressed();
  }

  @override
  Widget build(BuildContext context) {
    var scheme = Theme.of(context).colorScheme;
    var ringColor = widget.isLiked ? (widget.color ?? scheme.primary) : widget.color;

    return TextButton.icon(
      onPressed: _handleTap,
      style: footerButtonStyle,
      icon: SizedBox(
        width: _iconSize,
        height: _iconSize,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned(
              // Centre the larger burst canvas over the 20px icon without shifting layout.
              left: (_iconSize - _burstSize) / 2,
              top: (_iconSize - _burstSize) / 2,
              child: IgnorePointer(
                child: CustomPaint(
                  size: const Size.square(_burstSize),
                  painter: _BurstPainter(animation: _controller, color: ringColor ?? scheme.primary),
                ),
              ),
            ),
            ScaleTransition(
              scale: _scale,
              child: Icon(widget.isLiked ? Icons.favorite : Icons.favorite_border, size: _iconSize, color: widget.color),
            ),
          ],
        ),
      ),
      label: Text(widget.label, style: TextStyle(color: widget.color, fontSize: 14)),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _BurstPainter({required this.animation, required this.color}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    var t = animation.value;
    if (t == 0) {
      return;
    }

    var center = size.center(Offset.zero);
    var maxRadius = size.width / 2;

    _paintRing(canvas, center, maxRadius, t);
    _paintConfetti(canvas, center, maxRadius, t);
  }

  void _paintRing(Canvas canvas, Offset center, double maxRadius, double t) {
    const window = 0.72;
    if (t > window) {
      return;
    }

    // A gentle start (easeInOutCubic) so the ring is seen growing out of the
    // heart's centre rather than appearing already expanded.
    var rt = Curves.easeInOutCubic.transform(t / window);
    var radius = lerpDouble(0, maxRadius, rt)!;
    if (radius <= 0) {
      return;
    }

    var paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = lerpDouble(maxRadius * 0.3, 0.5, rt)!
      ..color = color.withValues(alpha: (1 - rt) * 0.85);

    canvas.drawCircle(center, radius, paint);
  }

  void _paintConfetti(Canvas canvas, Offset center, double maxRadius, double t) {
    const start = 0.3;
    if (t < start) {
      return;
    }

    var p = ((t - start) / (1 - start)).clamp(0.0, 1.0);
    var ease = Curves.easeOut.transform(p);
    var fade = (1 - p).clamp(0.0, 1.0);
    var dotRadius = math.sin(p * math.pi) * 1.7;
    if (dotRadius <= 0) {
      return;
    }

    // Two interleaved rings of dots, offset in angle and reach.
    _paintRingOfDots(canvas, center, count: 6, angleOffset: 0, reach: maxRadius, dotRadius: dotRadius, ease: ease, fade: fade);
    _paintRingOfDots(canvas, center, count: 6, angleOffset: math.pi / 6, reach: maxRadius * 0.72,
        dotRadius: dotRadius * 0.7, ease: ease, fade: fade);
  }

  void _paintRingOfDots(Canvas canvas, Offset center,
      {required int count,
      required double angleOffset,
      required double reach,
      required double dotRadius,
      required double ease,
      required double fade}) {
    var distance = lerpDouble(reach * 0.28, reach, ease)!;

    for (var i = 0; i < count; i++) {
      var angle = (2 * math.pi * i / count) + angleOffset;
      var offset = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      var paint = Paint()..color = color.withValues(alpha: fade);
      canvas.drawCircle(offset, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.color != color;
}
