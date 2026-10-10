import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/constants.dart';

/// The space a header laid over a feed takes at the top, which the feed leaves empty so its first item starts below
/// the header, while the rest of it scrolls underneath.
class XHeaderInset extends InheritedWidget {
  final double inset;

  const XHeaderInset({super.key, required this.inset, required super.child});

  /// 0 when the feed has no header laid over it
  static double of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<XHeaderInset>()?.inset ?? 0;

  @override
  bool updateShouldNotify(XHeaderInset oldWidget) => inset != oldWidget.inset;
}

/// A feed with its [header] laid over it, as in X: the body fills the screen and scrolls under the header, which
/// slides out of view when scrolling down and comes back when scrolling up.
class XOverlayFeed extends StatefulWidget {
  /// The height of the header below the status bar
  final double headerHeight;
  final ScrollController scrollController;
  final Widget header;
  final Widget body;

  const XOverlayFeed({
    super.key,
    required this.headerHeight,
    required this.scrollController,
    required this.header,
    required this.body,
  });

  @override
  State<XOverlayFeed> createState() => _XOverlayFeedState();
}

class _XOverlayFeedState extends State<XOverlayFeed> {
  static const _slideDuration = Duration(milliseconds: 200);

  bool _headerVisible = true;

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) return false;
    final visible = switch (notification) {
      UserScrollNotification(direction: ScrollDirection.reverse) => false,
      UserScrollNotification(direction: ScrollDirection.forward) => true,
      ScrollUpdateNotification(:final metrics) when metrics.pixels <= metrics.minScrollExtent => true,
      _ => _headerVisible,
    };
    if (visible != _headerVisible) setState(() => _headerVisible = visible);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final inset = media.padding.top + widget.headerHeight;
    final disableAnimations = PrefService.of(context).get<bool>(optionDisableAnimations) ?? false;

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: XHeaderInset(
              inset: inset,
              child: MediaQuery(
                data: media.copyWith(padding: media.padding.copyWith(top: inset)),
                child: RepaintBoundary(
                  child: PrimaryScrollController(controller: widget.scrollController, child: widget.body),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: _headerVisible ? Offset.zero : const Offset(0, -1),
            duration: disableAnimations ? Duration.zero : _slideDuration,
            curve: Curves.easeOut,
            child: widget.header,
          ),
        ),
      ],
    );
  }
}
