import 'package:flutter_triple/flutter_triple.dart';

/// Loads what a page shows, such as a community or a list, and keeps it.
class LoadedStore<T extends Object> extends Store<T> {
  final Future<T> Function() _fetch;

  LoadedStore(super.initialState, this._fetch);

  Future<void> load() {
    // execute() only says it is loading after a short delay. Until then, the page would show the empty first state
    setLoading(true);
    return execute(_fetch);
  }
}
