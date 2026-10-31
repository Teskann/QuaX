import 'dart:async';
import 'dart:convert';

import 'package:dart_twitter_api/twitter_api.dart' show AbstractTwitterClient;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:quax/client/client.dart';
import 'package:quax/space/space_model.dart';

/// X never answers, so a store stays loading.
class _SilentX extends AbstractTwitterClient {
  @override
  Future<Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) => Completer<Response>().future;

  @override
  Future<Response> post(Uri uri, {Map<String, String>? headers, dynamic body, Encoding? encoding, Duration? timeout}) =>
      Completer<Response>().future;

  @override
  Future<Response> multipartRequest(
    Uri uri, {
    List<MultipartFile>? files,
    Map<String, String>? headers,
    Duration? timeout,
  }) => Completer<Response>().future;
}

void main() {
  setUp(() => Twitter.client = _SilentX());

  test('Should say a space is loading as soon as it is asked for', () {
    final model = SpaceModel('1')..load();

    expect(
      model.isLoading,
      isTrue,
      reason: 'Until X answers, the card would show an empty space that has not started yet',
    );
  });

  test('Should say the audio of a space is loading as soon as it is asked for', () {
    final model = SpaceStreamModel('28_1')..load();

    expect(model.isLoading, isTrue, reason: 'Until X answers, the player would start on an empty playlist');
  });
}
