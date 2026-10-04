import 'dart:convert';

import 'package:quax/client/client.dart';

import '../fixtures.dart';

const grokShareTweet = '2098507671083036843';
const carouselTweet = '2082854732020760880';
const imageWebsiteTweet = '2091848397166895354';

/// The tweet [id] as the app reads it from its recorded TweetDetail.
TweetWithCard detailTweet(String id) => Twitter.parseTweetDetail(fixture('TweetDetail', id).body)
    .chains
    .expand((chain) => chain.tweets)
    .firstWhere((tweet) => tweet.idStr == id);

/// The tweet [id] of the recorded home timeline, read the way the app reads any tweet result. The app itself drops the
/// promoted ones of a timeline, which is what the image website cards of this recording are.
TweetWithCard homeTweet(String id) => TweetWithCard.fromGraphqlJson(_findResult(fixture('HomeTimeline', 'vars-2a4d9c').body, id)!);

Map<String, dynamic>? _findResult(Object? node, String id) {
  if (node is Map<String, dynamic>) {
    if (node['rest_id'] == id && node['legacy'] != null) return node;
    return node.values.map((child) => _findResult(child, id)).nonNulls.firstOrNull;
  }
  return node is List ? node.map((child) => _findResult(child, id)).nonNulls.firstOrNull : null;
}

/// The card of the tweet [id] exactly as X sent it, its binding values still a list.
Map<String, dynamic> rawCard(String id) {
  Map<String, dynamic>? find(Object? node) {
    if (node is Map<String, dynamic>) {
      if (node['rest_id'] == id && node['card']?['legacy'] != null) return node['card']['legacy'];
      return node.values.map(find).nonNulls.firstOrNull;
    }
    return node is List ? node.map(find).nonNulls.firstOrNull : null;
  }

  return _copy(find(fixture('TweetDetail', id).body)!);
}

Map<String, dynamic> _copy(Map<String, dynamic> json) => jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

Map<String, dynamic> _unifiedEntry(Map<String, dynamic> card) {
  final values = card['binding_values'];
  return (values is Map ? values['unified_card'] : (values as List).firstWhere((e) => e['key'] == 'unified_card')['value'])
      as Map<String, dynamic>;
}

/// The content of the unified card, a JSON string inside the card.
Map<String, dynamic> unifiedOf(Map<String, dynamic> card) =>
    jsonDecode(_unifiedEntry(card)['string_value'] as String) as Map<String, dynamic>;

/// A copy of [card] whose unified card went through [edit], to break one thing of a real card at a time.
Map<String, dynamic> withUnified(Map<String, dynamic> card, void Function(Map<String, dynamic> unified) edit) {
  final copy = _copy(card);
  final unified = unifiedOf(copy);
  edit(unified);
  _unifiedEntry(copy)['string_value'] = jsonEncode(unified);
  return copy;
}

/// The card [card] of a tweet, as the tweet carries it once read by the app.
Map<String, dynamic> cardOf(TweetWithCard tweet) => _copy(tweet.card!);
