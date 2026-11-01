import 'package:flutter/rendering.dart';

typedef _LaidOutItem = ({int index, double top, double bottom});

/// Returns the first item whose top is visible. If there is none, returns the item that covers the top of the screen.
int? topItemIndex({required RenderBox viewport, required int anchor, RenderObject? above, RenderObject? below}) {
  final top = viewport.localToGlobal(Offset.zero).dy;
  final bottom = top + viewport.size.height;
  final visible = [
    ..._children(above).map((child) => (index: anchor - 1 - child.index, top: child.top, bottom: child.bottom)),
    ..._children(below).map((child) => (index: anchor + child.index, top: child.top, bottom: child.bottom)),
  ].where((child) => child.bottom > top);
  return (_highest(visible.where((child) => child.top >= top && child.top < bottom)) ?? _highest(visible))?.index;
}

_LaidOutItem? _highest(Iterable<_LaidOutItem> items) =>
    items.fold<_LaidOutItem?>(null, (highest, item) => highest == null || item.top < highest.top ? item : highest);

Iterable<_LaidOutItem> _children(RenderObject? sliver) sync* {
  if (sliver is! RenderSliverMultiBoxAdaptor) return;
  for (var child = sliver.firstChild; child != null; child = sliver.childAfter(child)) {
    final top = child.localToGlobal(Offset.zero).dy;
    yield (
      index: (child.parentData as SliverMultiBoxAdaptorParentData).index!,
      top: top,
      bottom: top + child.size.height
    );
  }
}
