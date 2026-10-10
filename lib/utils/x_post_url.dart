/// X's own page to reply to a post, shown in QuaX where the user is signed in to X
String xReplyIntentUri(String tweetId) => 'https://x.com/intent/post?in_reply_to=$tweetId';

/// X's own page to repost a post
String xRepostIntentUri(String tweetId) => 'https://x.com/intent/retweet?tweet_id=$tweetId';

bool _isIntent(Uri uri) => uri.path.startsWith('/intent/');

/// Whether X moved on from the intent page [initial], for instance to the home page once the action was sent.
/// A query-only change stays on the same page, and a page that was not an intent is never "finished".
bool xIntentFinished(Uri initial, Uri current) => _isIntent(initial) && !_isIntent(current);
