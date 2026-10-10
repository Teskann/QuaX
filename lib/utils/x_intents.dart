import 'package:flutter/widgets.dart' show BuildContext;

// The web intents of X, which QuaX uses to act on a post since it cannot post by itself. The X app or the browser
// takes over from there.

/// Opens an address outside the app, as `openUri` does
typedef UriOpener = Future<void> Function(BuildContext context, String uri);

const _intentBase = 'https://x.com/intent';

String xTweetUrl(String screenName, String tweetId) => 'https://x.com/$screenName/status/$tweetId';

String xReplyIntentUrl(String tweetId, String text) =>
    '$_intentBase/post?in_reply_to=$tweetId&text=${Uri.encodeComponent(text)}';

String xRepostIntentUrl(String tweetId) => '$_intentBase/retweet?tweet_id=$tweetId';

String xQuoteIntentUrl(String screenName, String tweetId) =>
    '$_intentBase/post?url=${Uri.encodeComponent(xTweetUrl(screenName, tweetId))}';
