/// The address of a post on X, which QuaX opens for replying or reposting since it cannot post by itself. The X app
/// takes over when it is installed, the browser otherwise.
String xPostUri(String? screenName, String tweetId) => 'https://x.com/${screenName ?? 'i'}/status/$tweetId';
