import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/x_post_url.dart';

void main() {
  group('xPostUri', () {
    test('Should build the address of the post from its author and id', () {
      expect(xPostUri('jack', '20'), 'https://x.com/jack/status/20', reason: 'The address names the author');
    });

    test('Should fall back to the generic address when the author is unknown', () {
      expect(xPostUri(null, '20'), 'https://x.com/i/status/20', reason: 'X resolves the post from its id alone');
    });
  });

  group('xReplyIntentUri', () {
    test('Should build the address of the page where X lets the user reply to the post', () {
      expect(xReplyIntentUri('20'), 'https://x.com/intent/post?in_reply_to=20',
          reason: 'X replies to the post named by in_reply_to');
    });
  });

  group('xRepostIntentUri', () {
    test('Should build the address of the page where X lets the user repost the post', () {
      expect(xRepostIntentUri('20'), 'https://x.com/intent/retweet?tweet_id=20',
          reason: 'X reposts the post named by tweet_id');
    });
  });

  group('xIntentFinished', () {
    final intent = Uri.parse('https://x.com/intent/post?in_reply_to=20');

    test('Should not be finished while still on the same intent page', () {
      expect(xIntentFinished(intent, intent), isFalse, reason: 'Nothing moved');
    });

    test('Should not be finished when only the query changed on the intent page', () {
      expect(xIntentFinished(intent, Uri.parse('https://x.com/intent/post?in_reply_to=20&text=hi')), isFalse,
          reason: 'The path is still the intent one');
    });

    test('Should not be finished when moving to another intent page', () {
      expect(xIntentFinished(intent, Uri.parse('https://x.com/intent/post/complete')), isFalse,
          reason: 'Every page under /intent/ belongs to the action');
    });

    test('Should be finished once X leaves the intent pages for the home page', () {
      expect(xIntentFinished(intent, Uri.parse('https://x.com/home')), isTrue, reason: 'X moved on after the action');
    });

    test('Should be finished once X leaves the intent pages for the post', () {
      expect(xIntentFinished(intent, Uri.parse('https://x.com/jack/status/20')), isTrue,
          reason: 'Any page outside /intent/ means the action is over');
    });

    test('Should never be finished when the first page was not an intent page', () {
      final login = Uri.parse('https://x.com/i/flow/login');

      expect(xIntentFinished(login, Uri.parse('https://x.com/home')), isFalse, reason: 'It did not start on the action');
      expect(xIntentFinished(login, login), isFalse, reason: 'Nor does staying on the login page');
      expect(xIntentFinished(login, intent), isFalse, reason: 'Nor does arriving on the intent page later');
    });
  });
}
