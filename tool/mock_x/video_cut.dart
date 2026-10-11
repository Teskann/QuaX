/// ffmpeg's freezedetect filter: a still lasting a second, ignoring changes too small to be the app
/// reacting (the clock of the status bar, an icon leaving the dock), whatever the theme.
const freezeFilter = 'freezedetect=n=-50dB:d=1';

const _margin = Duration(milliseconds: 500);
final _freezeStart = RegExp(r'freeze_start: (\d+(?:\.\d+)?)');
final _freezeEnd = RegExp(r'freeze_end: (\d+(?:\.\d+)?)');

/// Where to start a video so that it skips the still screen shown while Maestro starts: half a second
/// before that still ends, read from the output of [freezeFilter]. Null when the video should be kept whole.
Duration? cutPoint(String freezedetectOutput) {
  final start = _seconds(_freezeStart.firstMatch(freezedetectOutput));
  final end = _seconds(_freezeEnd.firstMatch(freezedetectOutput));
  if (start == null || end == null || start > const Duration(seconds: 1)) return null;
  final cut = end - _margin;
  return cut > Duration.zero ? cut : null;
}

Duration? _seconds(RegExpMatch? match) {
  final seconds = double.tryParse(match?.group(1) ?? '');
  return seconds == null ? null : Duration(microseconds: (seconds * Duration.microsecondsPerSecond).round());
}
