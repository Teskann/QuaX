import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/group/topic_timeline.dart';
import 'package:quax/home/_x_topic_catalog.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/trends/trends_model.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';

typedef TrendNamesLoader = Future<List<String>> Function();

/// Makes a timeline of the search [query] named [name], and returns the id of its group.
typedef TopicTimelineCreator = Future<String> Function(String name, String query);

const _maxTrends = 10;

/// The search that finds a trend: a trend of several words is searched as a phrase.
String trendQuery(String name) => name.contains(RegExp(r'\s')) ? '"$name"' : name;

/// The names of the trends of the active location.
Future<List<String>> loadActiveTrendNames(int woeid) async {
  final trends = await Twitter.getTrends(woeid);
  return trends
      .expand((place) => place.trends ?? const [])
      .map((trend) => trend.name)
      .whereType<String>()
      .toList(growable: false);
}

class XTrendingTopicsModel extends Store<List<String>> {
  final TrendNamesLoader _load;

  XTrendingTopicsModel(this._load) : super(const []);

  Future<void> load() => execute(() async => (await _load()).take(_maxTrends).toList(growable: false));
}

/// Where the user picks the topic of a new timeline: a custom search, a trend or a ready-made topic. Pops with the id
/// of the group of the timeline.
class XTopicsScreen extends StatefulWidget {
  final TrendNamesLoader? loadTrends;
  final TopicTimelineCreator? createTimeline;

  const XTopicsScreen({super.key, this.loadTrends, this.createTimeline});

  @override
  State<XTopicsScreen> createState() => _XTopicsScreenState();
}

class _XTopicsScreenState extends State<XTopicsScreen> {
  late final XTrendingTopicsModel _trends;
  late final TopicTimelineCreator _create;
  final _controller = TextEditingController();
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _trends = XTrendingTopicsModel(widget.loadTrends ?? _loadActiveTrends);
    _create = widget.createTimeline ?? _createAndReload;
    _trends.load();
  }

  Future<List<String>> _loadActiveTrends() =>
      loadActiveTrendNames(context.read<UserTrendLocationModel>().state.active.woeid ?? 1);

  Future<String> _createAndReload(String name, String query) async {
    final subscriptions = context.read<SubscriptionsModel>();
    final id = await createTopicTimeline(context.read<GroupsModel>(), name, query);
    await subscriptions.reloadSubscriptions();
    return id;
  }

  @override
  void dispose() {
    _controller.dispose();
    _trends.destroy();
    super.dispose();
  }

  Future<void> _add(String name, String query) async {
    if (_adding) return;
    _adding = true;
    try {
      final id = await _create(name, query);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context).timeline_added)));
      Navigator.pop(context, id);
    } finally {
      _adding = false;
    }
  }

  void _submit(String text) {
    final topic = text.trim();
    if (topic.isNotEmpty) _add(topic, topic);
  }

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    final l10n = L10n.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        title: Text(l10n.add_timelines, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        children: [
          _SearchField(controller: _controller, onSubmitted: _submit),
          _TrendingSection(model: _trends, onAdd: (name) => _add(name, trendQuery(name))),
          _SectionTitle(l10n.topics),
          ...xTopics.map((topic) => _TopicRow(
                icon: topic.icon,
                name: topic.name(l10n),
                onAdd: () => _add(topic.name(l10n), topic.query(l10n)),
              )),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const _SearchField({required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: L10n.of(context).search_for_a_topic,
          prefixIcon: Icon(XIcons.search, color: colors.secondaryText),
          filled: true,
          fillColor: colors.divider,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: XStyleColors.of(context).primaryText)),
    );
  }
}

class _TrendingSection extends StatelessWidget {
  final XTrendingTopicsModel model;
  final ValueChanged<String> onAdd;

  const _TrendingSection({required this.model, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ScopedBuilder<XTrendingTopicsModel, List<String>>(
      store: model,
      onLoading: (_) => const SizedBox.shrink(),
      onError: (_, _) => const SizedBox.shrink(),
      onState: (context, names) => names.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(L10n.of(context).trending),
                ...names.map((name) => _TopicRow(icon: XIcons.hash, name: name, onAdd: () => onAdd(name))),
              ],
            ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final VoidCallback onAdd;

  const _TopicRow({required this.icon, required this.name, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    return ListTile(
      leading: Icon(icon, color: colors.primaryText),
      title: Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.primaryText)),
      trailing: IconButton.outlined(
        tooltip: L10n.of(context).add,
        icon: Icon(XIcons.plus, color: colors.primaryText),
        onPressed: onAdd,
      ),
      onTap: onAdd,
    );
  }
}
