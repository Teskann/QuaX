import 'package:dart_twitter_api/twitter_api.dart' show User;
import 'package:material_ui/material_ui.dart';
import 'package:pref/pref.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/tweet/tweet_action_display.dart';
import 'package:quax/tweet/tweet_actions.dart';
import 'package:quax/ui/labeled_pref.dart';

class SettingsTweetActionsFragment extends StatefulWidget {
  const SettingsTweetActionsFragment({super.key});

  @override
  State<SettingsTweetActionsFragment> createState() => _SettingsTweetActionsFragmentState();
}

class _SettingsTweetActionsFragmentState extends State<SettingsTweetActionsFragment> {
  late final BasePrefService _prefs = PrefService.of(context, listen: false);

  // Captured before the config is stored, so the badges last the whole visit
  late final Set<TweetAction> _newActions;

  @override
  void initState() {
    super.initState();
    final config = parseTweetActions(_prefs.get<String>(optionTweetActions));
    _newActions = config.newActions;
    WidgetsBinding.instance.addPostFrameCallback((_) => _save(config));
  }

  Future<void> _save(TweetActionsConfig config) async => _prefs.set(optionTweetActions, config.encode());

  @override
  Widget build(BuildContext context) {
    final config = parseTweetActions(PrefService.of(context).get<String>(optionTweetActions));

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).customize_action_bar),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: L10n.of(context).reset_to_default,
            onPressed: () => _save(defaultTweetActions),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        header: const _Preview(),
        itemCount: config.settings.length,
        onReorderItem: (oldIndex, newIndex) => _save(config.withMoved(oldIndex, newIndex)),
        itemBuilder: (context, index) => _ActionRow(
          key: ValueKey(config.settings[index].action),
          setting: config.settings[index],
          isNew: _newActions.contains(config.settings[index].action),
          index: index,
          onToggle: () => _save(config.withToggled(config.settings[index].action)),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final TweetActionSetting setting;
  final bool isNew;
  final int index;
  final VoidCallback onToggle;

  const _ActionRow({
    super.key,
    required this.setting,
    required this.isNew,
    required this.index,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final label = tweetActionLabel(context, setting.action);

    return LabeledPref(
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 8, right: 16),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_indicator)),
            ),
            const SizedBox(width: 8),
            Icon(tweetActionIcon(setting.action)),
          ],
        ),
        title: Row(
          children: [
            Flexible(child: Text(label)),
            if (isNew) ...[const SizedBox(width: 8), const NewBadge()],
          ],
        ),
        trailing: Switch(value: setting.enabled, onChanged: (_) => onToggle()),
        onTap: onToggle,
      ),
    );
  }
}

class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Badge(label: Text(L10n.of(context).new_badge), backgroundColor: colors.primary, textColor: colors.onPrimary);
  }
}

const _quaxIcon = 'assets/icon.png';

class _Preview extends StatelessWidget {
  const _Preview();

  TweetWithCard _sampleTweet(BuildContext context) {
    final text = L10n.of(context).action_bar_preview_text;
    return TweetWithCard()
      ..idStr = '0'
      ..fullText = text
      ..displayTextRange = [0, text.length]
      ..createdAt = DateTime.now().subtract(const Duration(hours: 2))
      ..replyCount = 48
      ..retweetCount = 9
      ..quoteCount = 3
      ..favoriteCount = 1200
      ..viewCount = 8400
      ..user = (User()
        ..name = 'QuaX'
        ..screenName = 'QuaX'
        ..profileImageUrlHttps = _quaxIcon);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        child: IgnorePointer(child: TweetTile(clickable: false, tweet: _sampleTweet(context), addSeparator: false)),
      ),
    );
  }
}
