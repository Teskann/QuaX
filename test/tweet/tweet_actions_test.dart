import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/tweet/tweet_actions.dart';

String stored(List<Object> entries) => jsonEncode(entries);

void main() {
  group('parseTweetActions()', () {
    test('Should give the legacy bar, and only it, when nothing is stored', () {
      final config = parseTweetActions('');
      expect(config.enabled, legacyTweetActions, reason: 'A fresh bar should look like the bar before customization');
      expect(config.disabled, [
        TweetAction.copyLink,
        TweetAction.copyText,
        TweetAction.download,
        TweetAction.more,
      ], reason: 'The buttons added with customization, "more" included, should start hidden');
      expect(config.newActions, isEmpty, reason: 'Nothing is new to someone who never had a bar');
    });

    test('Should flag as new and hidden the actions an upgraded install never stored', () {
      final config = parseTweetActions(initialTweetActions(upgrading: true).encode());
      expect(config.newActions, {
        TweetAction.copyLink,
        TweetAction.copyText,
        TweetAction.download,
        TweetAction.more,
      }, reason: 'The buttons added since the legacy bar should be badged');
      expect(config.enabled, legacyTweetActions, reason: 'An upgrade should keep the bar as it was');
      expect(
        config.settings.map((s) => s.action).skip(legacyTweetActions.length),
        config.newActions.toList(),
        reason: 'New actions should be appended after the stored ones',
      );
    });

    test('Should flag nothing on a fresh install', () {
      expect(
        parseTweetActions(initialTweetActions(upgrading: false).encode()).newActions,
        isEmpty,
        reason: 'A fresh install stores every action',
      );
    });

    test('Should not flag a disabled action as new', () {
      final config = parseTweetActions(defaultTweetActions.withToggled(TweetAction.views).encode());
      expect(config.newActions, isEmpty, reason: 'A hidden button is still stored, so it is not new');
      expect(config.disabled, contains(TweetAction.views), reason: 'The hidden button should stay hidden');
    });

    test('Should keep the stored order', () {
      final config = parseTweetActions(
        stored([
          {'id': 'share', 'enabled': true},
          {'id': 'reply', 'enabled': false},
        ]),
      );
      expect(config.settings.take(2).map((s) => s.action), [
        TweetAction.share,
        TweetAction.reply,
      ], reason: 'Stored actions should come first, in their order');
      expect(config.enabled.first, TweetAction.share, reason: 'The stored order should drive the bar');
    });

    test('Should drop unknown and duplicated actions', () {
      final config = parseTweetActions(
        stored([
          {'id': 'teleport', 'enabled': true},
          {'id': 'like', 'enabled': true},
          {'id': 'like', 'enabled': false},
          'garbage',
        ]),
      );
      expect(config.settings.length, TweetAction.values.length, reason: 'Each action should appear exactly once');
      expect(config.enabled, contains(TweetAction.like), reason: 'The first occurrence of an action should win');
    });

    test('Should fall back to the defaults on a corrupted config', () {
      expect(
        parseTweetActions('{not json').enabled,
        legacyTweetActions,
        reason: 'A broken pref must not break every tweet',
      );
    });
  });

  group('TweetActionsConfig', () {
    test('Should move an action to its new index', () {
      final moved = defaultTweetActions.withMoved(0, 2);
      expect(moved.settings.take(3).map((s) => s.action), [
        TweetAction.retweet,
        TweetAction.like,
        TweetAction.reply,
      ], reason: 'Replies dragged to the third row should land there');
    });

    test('Should round-trip through its encoding', () {
      final config = defaultTweetActions.withMoved(3, 0).withToggled(TweetAction.more);
      final parsed = parseTweetActions(config.encode());
      expect(
        parsed.settings.map((s) => s.toJson()),
        config.settings.map((s) => s.toJson()),
        reason: 'The stored config should read back identically',
      );
    });
  });
}
