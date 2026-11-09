/// A list of accounts made by someone on X. Its posts are the posts of its members.
class XList {
  final String id;
  final String name;
  final String? description;
  final int memberCount;
  final int followerCount;
  final String? bannerUrl;
  final XListOwner? owner;
  final List<String> followerAvatarUrls;

  const XList({
    required this.id,
    required this.name,
    this.description,
    this.memberCount = 0,
    this.followerCount = 0,
    this.bannerUrl,
    this.owner,
    this.followerAvatarUrls = const [],
  });

  /// Reads a ListByRestId body. Null when X sent no list.
  static XList? fromGraphql(Map<String, dynamic> body) => fromResult(body['data']?['list']);

  /// Reads the list of a ListByRestId body or of a search result. Null when it has no id.
  static XList? fromResult(dynamic result) {
    if (result is! Map<String, dynamic>) return null;
    final id = result['id_str'] as String?;
    if (id == null) return null;

    final description = result['description'] as String?;
    return XList(
      id: id,
      name: result['name'] as String? ?? '',
      description: description == null || description.isEmpty ? null : description,
      memberCount: result['member_count'] as int? ?? 0,
      followerCount: result['subscriber_count'] as int? ?? 0,
      bannerUrl: _bannerUrl(result),
      owner: XListOwner.fromResult(result['user_results']?['result']),
      followerAvatarUrls: _avatarUrls(result['facepile_urls']),
    );
  }

  /// The photos of a few followers. X sends tiny ones, so this asks for the normal size, which stays sharp.
  static List<String> _avatarUrls(dynamic urls) => (urls is List ? urls : const [])
      .whereType<String>()
      .map((url) => url.replaceFirst('_mini.', '_normal.'))
      .toList(growable: false);

  static String? _bannerUrl(Map<String, dynamic> result) =>
      (result['custom_banner_media'] ?? result['default_banner_media'])?['media_info']?['original_img_url'] as String?;
}

/// The account that made a list.
class XListOwner {
  final String id;
  final String name;
  final String screenName;
  final String? avatarUrl;

  const XListOwner({required this.id, required this.name, required this.screenName, this.avatarUrl});

  /// Null when X did not say who made the list.
  static XListOwner? fromResult(dynamic result) {
    if (result is! Map<String, dynamic>) return null;
    final id = result['rest_id'] as String?;
    final screenName = result['core']?['screen_name'] as String?;
    if (id == null || screenName == null) return null;
    return XListOwner(
      id: id,
      name: result['core']?['name'] as String? ?? screenName,
      screenName: screenName,
      avatarUrl: result['avatar']?['image_url'] as String?,
    );
  }
}
