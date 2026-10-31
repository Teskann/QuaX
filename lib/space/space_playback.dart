const playbackSpeeds = [1.0, 1.25, 1.5, 2.0];

const skipStep = Duration(seconds: 10);

/// The speed after [speed] in [playbackSpeeds], back to the first after the last.
double nextPlaybackSpeed(double speed) {
  final index = playbackSpeeds.indexWhere((candidate) => (candidate - speed).abs() < 0.01);
  return playbackSpeeds[(index + 1) % playbackSpeeds.length];
}

/// Where skipping [offset] from [position] lands, kept within a recording of [length].
Duration skipTarget(Duration position, Duration offset, Duration length) {
  final target = position + offset;
  if (target < Duration.zero) return Duration.zero;
  return target > length ? length : target;
}

Duration timeLeft(Duration position, Duration length) => position > length ? Duration.zero : length - position;
