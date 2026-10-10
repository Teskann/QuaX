import 'package:flutter/foundation.dart';

/// What the content of the X home feed uses to drive its tabs, provided by the feed screen.
class XFeedController {
  ValueChanged<String>? _onSelectGroup;

  void attach(ValueChanged<String> onSelectGroup) => _onSelectGroup = onSelectGroup;

  void detach() => _onSelectGroup = null;

  /// Selects the tab of the group [id], waiting for it to appear if the groups have not reloaded yet.
  void selectGroup(String id) => _onSelectGroup?.call(id);
}
