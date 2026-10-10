import 'package:flutter_test/flutter_test.dart';
import 'package:quax/utils/x_intents.dart';

void main() {
  group('x intents', () {
    test('Should build the reply intent with the id of the post and the encoded text', () {
      expect(xReplyIntentUrl('123', 'Hello, world & more?'),
          'https://x.com/intent/post?in_reply_to=123&text=Hello%2C%20world%20%26%20more%3F',
          reason: 'The text must survive the query string');
    });

    test('Should build the reply intent without text when nothing was typed', () {
      expect(xReplyIntentUrl('123', ''), 'https://x.com/intent/post?in_reply_to=123&text=',
          reason: 'X opens its composer on the post even with no text');
    });

    test('Should build the repost intent with the id of the post', () {
      expect(xRepostIntentUrl('123'), 'https://x.com/intent/retweet?tweet_id=123',
          reason: 'The repost intent is the retweet one of X');
    });

    test('Should build the quote intent with the encoded address of the post', () {
      expect(xQuoteIntentUrl('jack', '20'),
          'https://x.com/intent/post?url=https%3A%2F%2Fx.com%2Fjack%2Fstatus%2F20',
          reason: 'A quote is a new post that carries the address of the quoted one');
    });
  });
}
