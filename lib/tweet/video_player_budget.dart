import 'dart:math';

import 'package:flutter/services.dart';

/// Bytes a single player may buffer ahead. The player keeps that buffer on the
/// Java heap, which is shared by the whole app and is only 256 MB on a Pixel 6.
const videoBufferBytesPerPlayer = 24 * 1024 * 1024;

// Java heap left to the rest of the app, and what one player costs on top of
// its buffer (decoder bookkeeping, sample queues...).
const _appHeapReserveMb = 96;
const _heapPerPlayerMb = 32;
const _maxPlayers = 8;
const _fallbackPlayers = 2;

// Most of X's MP4 variants are below this. GIFs come with a bitrate of 0.
const _assumedBitrate = 6000000;

/// How many video players (GIFs included) may be alive at once on a device
/// whose Java heap is capped at [heapLimitMb] and which can run
/// [maxHardwareDecoders] hardware H.264 decoders at once (null when unknown).
int videoPlayerBudget({required int heapLimitMb, int? maxHardwareDecoders}) {
  final byHeap = (heapLimitMb - _appHeapReserveMb) ~/ _heapPerPlayerMb;
  final byDecoders = maxHardwareDecoders == null || maxHardwareDecoders <= 0 ? _maxPlayers : maxHardwareDecoders;
  return min(byHeap, byDecoders).clamp(1, _maxPlayers);
}

/// How many milliseconds of a video of [bitrate] bits per second fit in
/// [videoBufferBytesPerPlayer].
int maxBufferMsFor(int? bitrate) {
  final bitsPerSecond = bitrate == null || bitrate <= 0 ? _assumedBitrate : bitrate;
  return (videoBufferBytesPerPlayer * 8 * 1000 ~/ bitsPerSecond).clamp(2500, 600000);
}

bool isDecoderFailure(String? errorDescription) => errorDescription?.contains('MediaCodecVideoRenderer') ?? false;

Future<int> loadVideoPlayerBudget() async {
  try {
    final hardware = await const MethodChannel('browser_resolver').invokeMapMethod<String, int>('getVideoHardware');
    final heapLimitMb = hardware?['heapLimitMb'];
    if (heapLimitMb == null) return _fallbackPlayers;
    return videoPlayerBudget(heapLimitMb: heapLimitMb, maxHardwareDecoders: hardware?['maxHardwareDecoders']);
  } on MissingPluginException {
    return _fallbackPlayers;
  } on PlatformException {
    return _fallbackPlayers;
  }
}
