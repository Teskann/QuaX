class Community {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final String? bannerUrl;
  final String? topic;
  final DateTime? createdAt;
  final List<String> rules;
  final List<String> memberAvatarUrls;

  const Community({
    required this.id,
    required this.name,
    this.description,
    this.memberCount = 0,
    this.bannerUrl,
    this.topic,
    this.createdAt,
    this.rules = const [],
    this.memberAvatarUrls = const [],
  });

  /// Reads a CommunityQuery body; null when X sent no community.
  static Community? fromGraphql(Map<String, dynamic> body) => fromResult(body['data']?['communityResults']?['result']);

  static Community? fromResult(dynamic result) {
    if (result is! Map<String, dynamic> || result['__typename'] != 'Community') return null;

    final id = result['rest_id'] as String? ?? result['id_str'] as String?;
    if (id == null) return null;

    final createdAt = result['created_at'] as int?;
    return Community(
      id: id,
      name: result['name'] as String? ?? '',
      description: result['description'] as String?,
      memberCount: result['member_count'] as int? ?? 0,
      bannerUrl: _bannerUrl(result),
      topic: result['primary_community_topic']?['topic_name'] as String?,
      createdAt: createdAt == null ? null : DateTime.fromMillisecondsSinceEpoch(createdAt),
      rules: _strings(result['rules'], (rule) => rule['name']),
      memberAvatarUrls: _strings(result['members_facepile_results'], (m) => m['result']?['avatar']?['image_url']),
    );
  }

  static String? _bannerUrl(Map<String, dynamic> result) =>
      (result['custom_banner_media'] ?? result['default_banner_media'])?['media_info']?['original_img_url'] as String?;

  static List<String> _strings(dynamic list, dynamic Function(Map<String, dynamic>) read) => (list is List ? list : const [])
      .whereType<Map<String, dynamic>>()
      .map(read)
      .whereType<String>()
      .toList(growable: false);
}
