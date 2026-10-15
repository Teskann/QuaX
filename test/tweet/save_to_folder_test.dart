import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/saved/saved_tweet_folder_model.dart';

import '../fixtures.dart';
import '../ui/fake_images.dart';
import 'pump_tweets.dart';

class _CountingFolders extends SavedTweetFolderModel {
  int listed = 0;

  @override
  Future<void> listFolders() async => listed++;
}

void main() {
  setUpAll(() => HttpOverrides.global = FakeImageHttpOverrides());

  testWidgets('Should open the folder picker on a long press of the save button of a post', (tester) async {
    final folders = _CountingFolders();
    await pumpChains(tester, Twitter.parseTweetDetail(fixture('TweetDetail', '2095921351106146703').body).chains,
        aboveApp: (app) => Provider<SavedTweetFolderModel>.value(value: folders, child: app));

    await tester.longPress(find.byIcon(Icons.bookmark_border).first);
    await tester.pump();

    expect(folders.listed, 1,
        reason: 'A long press on the save button files the post in a folder');
  });
}
