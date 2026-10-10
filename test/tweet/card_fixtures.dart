import 'dart:convert';

import 'package:quax/client/client.dart';

import '../fixtures.dart';

const grokShareTweet = '2098507671083036843';
const carouselTweet = '2082854732020760880';

/// The tweet [id] as the app reads it from its recorded TweetDetail.
TweetWithCard detailTweet(String id) => Twitter.parseTweetDetail(fixture('TweetDetail', id).body)
    .chains
    .expand((chain) => chain.tweets)
    .firstWhere((tweet) => tweet.idStr == id);

/// The first image website card of the recorded home timeline, read the way the app reads any tweet result. These
/// cards are ads, which the app drops from a timeline and which change with every recording, hence no fixed id.
TweetWithCard imageWebsiteTweet() => TweetWithCard.fromGraphqlJson(_maps(fixture('HomeTimeline', 'vars-2a4d9c', unstable: true).body)
    .firstWhere((node) => node['rest_id'] != null && node['legacy'] != null && _unifiedType(node) == 'image_website'));

String? _unifiedType(Map<String, dynamic> tweet) {
  final card = tweet['card']?['legacy'] as Map<String, dynamic>?;
  final values = card?['binding_values'];
  if (values is! List || !values.any((e) => e['key'] == 'unified_card')) return null;
  return unifiedOf(card!)['type'] as String?;
}

Iterable<Map<String, dynamic>> _maps(Object? node) sync* {
  if (node is Map<String, dynamic>) {
    yield node;
    for (final child in node.values) {
      yield* _maps(child);
    }
  } else if (node is List) {
    for (final child in node) {
      yield* _maps(child);
    }
  }
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
