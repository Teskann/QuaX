import 'dart:convert';

enum TweetAction { reply, retweet, like, views, bookmark, share, translate, copyLink, copyText, download, more }

const legacyTweetActions = [
  TweetAction.reply,
  TweetAction.retweet,
  TweetAction.like,
  TweetAction.views,
  TweetAction.bookmark,
  TweetAction.share,
  TweetAction.translate,
];

class TweetActionSetting {
  final TweetAction action;
  final bool enabled;

  const TweetActionSetting(this.action, this.enabled);

  Map<String, dynamic> toJson() => {'id': action.name, 'enabled': enabled};

  static TweetActionSetting? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final action = TweetAction.values.asNameMap()[json['id']];
    return action == null ? null : TweetActionSetting(action, json['enabled'] as bool? ?? false);
  }
}

class TweetActionsConfig {
  final List<TweetActionSetting> settings;

  /// Added to the app since the user last opened the bar settings.
  final Set<TweetAction> newActions;

  const TweetActionsConfig(this.settings, [this.newActions = const {}]);

  List<TweetAction> get enabled => settings.where((s) => s.enabled).map((s) => s.action).toList();

  List<TweetAction> get disabled => settings.where((s) => !s.enabled).map((s) => s.action).toList();

  String encode() => jsonEncode(settings.map((s) => s.toJson()).toList());

  TweetActionsConfig withToggled(TweetAction action) => TweetActionsConfig(
    settings.map((s) => s.action == action ? TweetActionSetting(action, !s.enabled) : s).toList(),
    newActions,
  );

  TweetActionsConfig withMoved(int oldIndex, int newIndex) {
    final without = [...settings]..removeAt(oldIndex);
    return TweetActionsConfig([...without.take(newIndex), settings[oldIndex], ...without.skip(newIndex)], newActions);
  }
}

TweetActionSetting _defaultSetting(TweetAction action) =>
    TweetActionSetting(action, legacyTweetActions.contains(action));

final defaultTweetActions = TweetActionsConfig(TweetAction.values.map(_defaultSetting).toList());

final legacyTweetActionsConfig = TweetActionsConfig(
  legacyTweetActions.map((a) => TweetActionSetting(a, true)).toList(),
);

List<TweetActionSetting> _decode(String? stored) {
  try {
    final list = stored == null || stored.isEmpty ? const [] : jsonDecode(stored) as List;
    return list
        .map(TweetActionSetting.fromJson)
        .nonNulls
        .fold<Map<TweetAction, TweetActionSetting>>({}, (all, s) => all..putIfAbsent(s.action, () => s))
        .values
        .toList();
  } catch (_) {
    return const [];
  }
}

TweetActionsConfig parseTweetActions(String? stored) {
  final known = _decode(stored);
  if (known.isEmpty) {
    return defaultTweetActions;
  }

  final missing = TweetAction.values.where((a) => known.every((s) => s.action != a)).toList();
  return TweetActionsConfig([...known, ...missing.map(_defaultSetting)], missing.toSet());
}

TweetActionsConfig initialTweetActions({required bool upgrading}) =>
    upgrading ? legacyTweetActionsConfig : defaultTweetActions;
