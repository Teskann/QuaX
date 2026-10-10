import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/ui/x_icons.dart';

/// A ready-made topic: what the user reads, and the search behind its timeline.
class XTopic {
  final IconData icon;
  final String Function(L10n l10n) name;
  final String Function(L10n l10n) query;

  const XTopic(this.icon, this.name, this.query);
}

final xTopics = <XTopic>[
  XTopic(XIcons.topicNews, (l) => l.x_topic_news, (l) => l.x_topic_news_query),
  XTopic(XIcons.topicSports, (l) => l.x_topic_sports, (l) => l.x_topic_sports_query),
  XTopic(XIcons.topicFootball, (l) => l.x_topic_football, (l) => l.x_topic_football_query),
  XTopic(XIcons.topicTechnology, (l) => l.x_topic_technology, (l) => l.x_topic_technology_query),
  XTopic(XIcons.topicAi, (l) => l.x_topic_ai, (l) => l.x_topic_ai_query),
  XTopic(XIcons.topicScience, (l) => l.x_topic_science, (l) => l.x_topic_science_query),
  XTopic(XIcons.topicGaming, (l) => l.x_topic_gaming, (l) => l.x_topic_gaming_query),
  XTopic(XIcons.topicMusic, (l) => l.x_topic_music, (l) => l.x_topic_music_query),
  XTopic(XIcons.topicMovies, (l) => l.x_topic_movies, (l) => l.x_topic_movies_query),
  XTopic(XIcons.topicAnime, (l) => l.x_topic_anime, (l) => l.x_topic_anime_query),
  XTopic(XIcons.topicBusiness, (l) => l.x_topic_business, (l) => l.x_topic_business_query),
  XTopic(XIcons.topicCrypto, (l) => l.x_topic_crypto, (l) => l.x_topic_crypto_query),
  XTopic(XIcons.topicPolitics, (l) => l.x_topic_politics, (l) => l.x_topic_politics_query),
  XTopic(XIcons.topicHealth, (l) => l.x_topic_health, (l) => l.x_topic_health_query),
  XTopic(XIcons.topicSpace, (l) => l.x_topic_space, (l) => l.x_topic_space_query),
];
