import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/tweet/tweet_actions.dart';
import 'package:quax/utils/downloads.dart';

import '../fixtures.dart';
import '../ui/fake_images.dart';
import '../ui/pump_app.dart';
import 'pump_tweets.dart';

const _photosAndVideos = '2095920289687150903';
const _onePhoto = '2095918690092884214';

TweetWithCard _post(String id) => tweetsOf(Twitter.parseTweetDetail(fixture('TweetDetail', id).body).chains)
    .firstWhere((tweet) => tweet.idStr == id);

Future<void> _openMoreMenu(WidgetTester tester, String id) async {
  await pumpInApp(
    tester,
    withAppModels(SingleChildScrollView(child: TweetTile(clickable: true, tweet: _post(id)))),
    prefs: {optionTweetActions: defaultTweetActions.withToggled(TweetAction.more).encode()},
    settle: false,
  );
  await tester.pump();
  await tester.ensureVisible(find.byIcon(Icons.more_vert));
  await tester.pump();
  await tester.tap(find.byIcon(Icons.more_vert));
  // The media keep loading, so the page never settles
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _openViewer(WidgetTester tester, String id) {
  final post = _post(id);
  return pumpInApp(
    tester,
    TweetMediaView(initialIndex: 0, media: post.extendedEntities!.media!, username: post.user!.screenName!),
    settle: false,
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  group('Download all', () {
    testWidgets('Should be offered in the menu of a post with several media', (tester) async {
      await _openMoreMenu(tester, _photosAndVideos);

      expect(find.text('Download all'), findsOneWidget, reason: 'Four media are worth a single tap');
    });

    testWidgets('Should not be offered in the menu of a post with a single media', (tester) async {
      await _openMoreMenu(tester, _onePhoto);

      expect(find.text('Download all'), findsNothing, reason: 'Download already saves the only media');
    });

    testWidgets('Should be a button of the viewer of a post with several media', (tester) async {
      await _openViewer(tester, _photosAndVideos);

      expect(find.bySemanticsLabel('Download all'), findsOneWidget, reason: 'The viewer should save every media');
    });

    testWidgets('Should not be a button of the viewer of a single media', (tester) async {
      await _openViewer(tester, _onePhoto);

      expect(find.bySemanticsLabel('Download all'), findsNothing, reason: 'Download already saves the only media');
    });
  });

  group('mediaDownloads()', () {
    test('Should give the original photos and the best video of every media, in order', () async {
      final post = _post(_photosAndVideos);
      final downloads = await mediaDownloads(post.extendedEntities!.media!, 'quax_tests');

      expect(downloads.length, 4, reason: 'Each photo and video of the post should be downloaded');
      expect(
        downloads.take(2).map((d) => d.uri.toString()),
        everyElement(endsWith(':orig')),
        reason: 'Photos should be saved in their original size, as a single download does',
      );
      expect(
        downloads.skip(2).map((d) => d.uri.path),
        everyElement(endsWith('.mp4')),
        reason: 'Videos should be saved as an MP4, not as their HLS playlist',
      );
      expect(downloads.map((d) => d.fileName), everyElement(startsWith('quax_tests-')),
          reason: 'Files should be named after the author, as a single download does');
      expect(downloads.map((d) => d.fileName).toSet().length, 4, reason: 'No media should overwrite another');
    });
  });

  group('downloadAll()', () {
    final downloads = [1, 2, 3].map((i) => MediaDownload(Uri.parse('https://pbs.twimg.com/$i.jpg'), '$i.jpg'));

    test('Should save every media under its name, with the type X gave', () async {
      final saved = <String, String?>{};
      final count = await downloadAll(
        downloads,
        (fileName, response) async => saved[fileName] = response.headers['content-type'],
        client: MockClient((_) async => http.Response('', 200, headers: {'content-type': 'image/jpeg'})),
      );

      expect(count, 3, reason: 'Every media was answered');
      expect(saved, {'1.jpg': 'image/jpeg', '2.jpg': 'image/jpeg', '3.jpg': 'image/jpeg'},
          reason: 'The folder picker needs the type of each file');
    });

    test('Should go on after a media that fails, and not count it', () async {
      final saved = <String>[];
      final count = await downloadAll(
        downloads,
        (fileName, response) async => saved.add(fileName),
        client: MockClient((request) async =>
            request.url.path == '/2.jpg' ? throw const SocketException('offline') : http.Response('', 200)),
      );

      expect(count, 2, reason: 'The media that failed should not be counted as saved');
      expect(saved, ['1.jpg', '3.jpg'], reason: 'One failure should not stop the others');
    });

    test('Should not save a media X refused', () async {
      final saved = <String>[];
      final count = await downloadAll(
        downloads,
        (fileName, response) async => saved.add(fileName),
        client: MockClient((request) async => http.Response('', request.url.path == '/3.jpg' ? 404 : 200)),
      );

      expect(count, 2, reason: 'A 404 is not a media');
      expect(saved, isNot(contains('3.jpg')), reason: 'An error page should never be saved as a media');
    });

    test('Should download the media one after the other', () async {
      var running = 0;
      var mostAtOnce = 0;
      await downloadAll(
        downloads,
        (fileName, response) async {},
        client: MockClient((_) async {
          mostAtOnce = ++running > mostAtOnce ? running : mostAtOnce;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          running--;
          return http.Response('', 200);
        }),
      );

      expect(mostAtOnce, 1, reason: 'Twenty media at once would flood X');
    });
  });
}
