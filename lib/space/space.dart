enum SpaceState { scheduled, live, ended }

class SpaceUser {
  final String name;
  final String screenName;
  final String? avatarUrl;

  const SpaceUser({required this.name, required this.screenName, this.avatarUrl});

  static SpaceUser? fromParticipant(dynamic participant) {
    if (participant is! Map<String, dynamic>) return null;
    final screenName = participant['twitter_screen_name'] as String?;
    if (screenName == null) return null;
    return SpaceUser(
      name: participant['display_name'] as String? ?? screenName,
      screenName: screenName,
      avatarUrl: participant['avatar_url'] as String?,
    );
  }
}

class Space {
  final String id;
  final String title;
  final SpaceState state;
  final String? mediaKey;
  final bool hasRecording;
  final DateTime? scheduledStart;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int tunedInCount;
  final int listeningCount;
  final List<SpaceUser> hosts;
  final List<SpaceUser> speakers;

  const Space({
    required this.id,
    required this.title,
    required this.state,
    this.mediaKey,
    this.hasRecording = false,
    this.scheduledStart,
    this.startedAt,
    this.endedAt,
    this.tunedInCount = 0,
    this.listeningCount = 0,
    this.hosts = const [],
    this.speakers = const [],
  });

  bool get canPlay => mediaKey != null && (state == SpaceState.live || (state == SpaceState.ended && hasRecording));

  Duration? get duration {
    final start = startedAt;
    final end = endedAt;
    return start == null || end == null ? null : end.difference(start);
  }

  /// Reads an AudioSpaceById body; null when X sent no space.
  static Space? fromGraphql(Map<String, dynamic> body) {
    final audioSpace = body['data']?['audioSpace'];
    final metadata = audioSpace?['metadata'];
    if (metadata is! Map<String, dynamic>) return null;
    final id = metadata['rest_id'] as String?;
    final state = _state(metadata['state'] as String?);
    if (id == null || state == null) return null;

    return Space(
      id: id,
      title: metadata['title'] as String? ?? '',
      state: state,
      mediaKey: metadata['media_key'] as String?,
      hasRecording: metadata['is_space_available_for_replay'] as bool? ?? false,
      scheduledStart: _date(metadata['scheduled_start']),
      startedAt: _date(metadata['started_at']),
      endedAt: _date(metadata['ended_at']),
      tunedInCount: metadata['total_live_listeners'] as int? ?? 0,
      listeningCount: audioSpace?['participants']?['total'] as int? ?? 0,
      hosts: _users(audioSpace?['participants']?['admins']),
      speakers: _users(audioSpace?['participants']?['speakers']),
    );
  }

  static SpaceState? _state(String? state) => switch (state) {
    'NotStarted' || 'PrePublished' => SpaceState.scheduled,
    'Running' => SpaceState.live,
    // TimedOut and Canceled spaces are over too: a TimedOut one may even have a recording
    'Ended' || 'TimedOut' || 'Canceled' => SpaceState.ended,
    _ => null,
  };

  // X sends these times as numbers or as strings, in milliseconds
  static DateTime? _date(dynamic value) {
    final millis = value is int ? value : int.tryParse(value?.toString() ?? '');
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static List<SpaceUser> _users(dynamic participants) =>
      (participants is List ? participants : const []).map(SpaceUser.fromParticipant).nonNulls.toList(growable: false);
}
