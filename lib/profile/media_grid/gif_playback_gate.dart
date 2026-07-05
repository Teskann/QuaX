import 'package:flutter/foundation.dart';

/// Caps how many profile-grid GIFs decode at once.
///
/// Each visible GIF tile reports its visible fraction; the [maxConcurrent]
/// most-visible tiles are granted a live libmpv player and the rest fall back to
/// a static thumbnail. Without this a whole grid of GIFs spins up a player each
/// at once — exhausting the device's hardware decoders and lagging hard both on
/// open and while scrolling.
class GifPlaybackGate extends ChangeNotifier {
  final int maxConcurrent;
  GifPlaybackGate({this.maxConcurrent = 5});

  final Map<Object, double> _fractions = {};
  Set<Object> _granted = <Object>{};

  bool isGranted(Object token) => _granted.contains(token);

  void report(Object token, double fraction) {
    if (fraction > 0) {
      if (_fractions[token] == fraction) return;
      _fractions[token] = fraction;
    } else if (_fractions.remove(token) == null) {
      return;
    }
    _rebalance();
  }

  void forget(Object token) {
    final wasTracked = _fractions.remove(token) != null;
    if (wasTracked || _granted.contains(token)) _rebalance();
  }

  void _rebalance() {
    final ranked = _fractions.entries.toList()
      ..sort((a, b) {
        final byFraction = b.value.compareTo(a.value);
        if (byFraction != 0) return byFraction;
        // Break ties for the already-granted tile so equally-visible cells
        // (a screenful all at fraction 1.0) don't swap grants every tick.
        final ag = _granted.contains(a.key) ? 0 : 1;
        final bg = _granted.contains(b.key) ? 0 : 1;
        return ag.compareTo(bg);
      });

    final winners = ranked.take(maxConcurrent).map((e) => e.key).toSet();
    if (setEquals(winners, _granted)) return;
    _granted = winners;
    notifyListeners();
  }
}
