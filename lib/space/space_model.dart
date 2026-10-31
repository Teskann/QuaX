import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_triple/flutter_triple.dart';
import 'package:logging/logging.dart';
import 'package:quax/client/client.dart';
import 'package:quax/space/space.dart';

class SpaceModel extends Store<Space> {
  static final log = Logger('SpaceModel');

  // A feed rebuilds a card each time it scrolls back into view: a space already known shows at once, then refreshes
  static final Map<String, Space> _known = {};

  @visibleForTesting
  static void forgetKnownSpaces() => _known.clear();

  final String id;
  bool _destroyed = false;

  SpaceModel(this.id) : super(_known[id] ?? Space(id: id, title: '', state: SpaceState.scheduled));

  Future<void> load() => _known.containsKey(id) ? _refresh() : _loadUnknown();

  Future<void> _loadUnknown() {
    // execute() waits a moment before it says it is loading, which would show the empty space meanwhile
    setLoading(true);
    return execute(() async => _known[id] = await Twitter.getSpace(id));
  }

  // The known space stays on screen while X answers, and when it cannot
  Future<void> _refresh() async {
    try {
      final space = await Twitter.getSpace(id);
      _known[id] = space;
      if (!_destroyed) update(space);
    } on Exception catch (error) {
      log.warning('Could not refresh the space $id', error);
    }
  }

  @override
  Future destroy() {
    _destroyed = true;
    return super.destroy();
  }
}

class SpaceStreamModel extends Store<String> {
  final String mediaKey;

  SpaceStreamModel(this.mediaKey) : super('');

  Future<void> load() {
    // execute() waits a moment before it says it is loading, which would start a player on an empty playlist meanwhile
    setLoading(true);
    return execute(() => Twitter.getSpacePlaylist(mediaKey));
  }
}
