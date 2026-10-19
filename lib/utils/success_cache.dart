/// Computes a value on first use and keeps it. A failure is not kept: the next
/// call computes it again, so a transient error does not last until a restart.
class SuccessCache<T> {
  SuccessCache(this._compute);

  final Future<T> Function() _compute;
  Future<T>? _value;

  Future<T> call() => _value ??= _attempt();

  Future<T> _attempt() async {
    try {
      return await _compute();
    } catch (_) {
      _value = null;
      rethrow;
    }
  }
}
