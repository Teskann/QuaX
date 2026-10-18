import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/search/search_filter_fields.dart';
import 'package:quax/search/search_filter_labels.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/search/search_model.dart';

/// Edits the filters of a search, and gives them back when the results are asked for.
class SearchFiltersScreen extends StatefulWidget {
  final SearchFilters initial;

  const SearchFiltersScreen({super.key, required this.initial});

  static Future<SearchFilters?> open(BuildContext context, SearchFilters initial) => Navigator.push(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => SearchFiltersScreen(initial: initial)));

  @override
  State<SearchFiltersScreen> createState() => _SearchFiltersScreenState();
}

class _SearchFiltersScreenState extends State<SearchFiltersScreen> {
  late final SearchFiltersModel _draft = SearchFiltersModel(widget.initial);

  @override
  void dispose() {
    _draft.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: Icon(Icons.close, semanticLabel: l10n.close), onPressed: () => Navigator.pop(context)),
        title: Text(l10n.filters),
        actions: [TextButton(onPressed: () => _draft.set(SearchFilters.none), child: Text(l10n.search_filters_clear_all))],
      ),
      // In the body rather than the bottom bar, so the button rises with the keyboard
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ScopedBuilder<SearchFiltersModel, SearchFilters>(
              store: _draft,
              onState: (_, filters) => _FilterSections(filters: filters, onChanged: _draft.set),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: () => Navigator.pop(context, _draft.state),
              child: Text(l10n.search_filters_show_results),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FilterSections extends StatelessWidget {
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  const _FilterSections({required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final active = filters.active;
    String summary(bool Function(ActiveFilter) inSection) {
      final labels = active.where(inSection).map((filter) => activeFilterLabel(l10n, filter));
      return labels.isEmpty ? l10n.search_filters_no_filter : labels.join(', ');
    }

    return ListView(
      children: [
        _Section(
          title: l10n.language,
          summary: _languageSummary(context),
          initiallyExpanded: true,
          children: [_LanguageFilter(filters: filters, onChanged: onChanged)],
        ),
        _Section(
          title: l10n.search_filters_words,
          summary: summary((f) => f is AnyWordsFilter || f is NoneWordFilter || f is HashtagFilter),
          children: _wordFields(l10n),
        ),
        _Section(
          title: l10n.search_filters_accounts,
          summary: summary((f) => f is FromFilter || f is ToFilter || f is MentionFilter),
          children: _accountFields(l10n),
        ),
        _Section(
          title: l10n.search_filters_content,
          summary: summary((f) => f is RepliesFilter || f is LinksFilter || f is MediaTypeFilter || f is RepostsFilter),
          children: [_ContentFilters(filters: filters, onChanged: onChanged)],
        ),
        _Section(
          title: l10n.search_filters_engagement,
          summary: summary((f) => f is MinRepliesFilter || f is MinFavesFilter || f is MinRetweetsFilter),
          children: [_engagementFields(l10n)],
        ),
        _Section(
          title: l10n.search_filters_period,
          summary: summary((f) => f is SinceFilter || f is UntilFilter),
          children: [_periodFields(l10n)],
        ),
      ],
    );
  }

  String _languageSummary(BuildContext context) {
    final l10n = L10n.of(context);
    return switch (filters.language) {
      LanguageChoice.all => l10n.search_filters_all_languages,
      LanguageChoice.mine => l10n.search_filters_in_my_language(languageName(appSearchLanguage())),
      LanguageChoice.other => languageName(filters.otherLanguage),
    };
  }

  List<Widget> _wordFields(L10n l10n) => [
        FilterTextField(
            label: l10n.search_filters_any_words,
            value: filters.anyWords.join(' '),
            onChanged: (text) => onChanged(filters.copyWith(anyWords: splitWords(text)))),
        FilterTextField(
            label: l10n.search_filters_none_words,
            value: filters.noneWords.join(' '),
            onChanged: (text) => onChanged(filters.copyWith(noneWords: splitWords(text, prefix: '-')))),
        FilterTextField(
            label: l10n.search_filters_hashtags,
            value: filters.hashtags.join(' '),
            onChanged: (text) => onChanged(filters.copyWith(hashtags: splitWords(text, prefix: '#')))),
      ];

  List<Widget> _accountFields(L10n l10n) => [
        AccountsField(
            label: l10n.search_filters_from_accounts,
            accounts: filters.fromAccounts,
            onChanged: (accounts) => onChanged(filters.copyWith(fromAccounts: accounts))),
        AccountsField(
            label: l10n.search_filters_to_accounts,
            accounts: filters.toAccounts,
            onChanged: (accounts) => onChanged(filters.copyWith(toAccounts: accounts))),
        AccountsField(
            label: l10n.search_filters_mentions,
            accounts: filters.mentions,
            onChanged: (accounts) => onChanged(filters.copyWith(mentions: accounts))),
      ];

  Widget _engagementFields(L10n l10n) {
    Widget count(String label, int? value, SearchFilters Function(int?) apply) => Expanded(
          child: FilterTextField(
            label: label,
            value: value?.toString() ?? '',
            keyboardType: TextInputType.number,
            onChanged: (text) => onChanged(apply(int.tryParse(text.trim()))),
          ),
        );

    return Row(spacing: 8, children: [
      count(l10n.replies, filters.minReplies, (value) => filters.copyWith(minReplies: () => value)),
      count(l10n.search_filters_likes, filters.minFaves, (value) => filters.copyWith(minFaves: () => value)),
      count(l10n.reposts, filters.minRetweets, (value) => filters.copyWith(minRetweets: () => value)),
    ]);
  }

  Widget _periodFields(L10n l10n) => Row(spacing: 8, children: [
        Expanded(
            child: FilterDateField(
                label: l10n.search_filters_since,
                value: filters.since,
                onChanged: (date) => onChanged(filters.copyWith(since: () => date)))),
        Expanded(
            child: FilterDateField(
                label: l10n.search_filters_until,
                value: filters.until,
                onChanged: (date) => onChanged(filters.copyWith(until: () => date)))),
      ]);
}

class _Section extends StatelessWidget {
  final String title;
  final String summary;
  final bool initiallyExpanded;
  final List<Widget> children;

  const _Section({required this.title, required this.summary, required this.children, this.initiallyExpanded = false});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title),
      subtitle: Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
      initiallyExpanded: initiallyExpanded,
      shape: const Border(),
      childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: children)],
    );
  }
}

class _LanguageFilter extends StatelessWidget {
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  const _LanguageFilter({required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 12, children: [
      SegmentedButton<LanguageChoice>(
        segments: [
          ButtonSegment(value: LanguageChoice.all, label: Text(l10n.all)),
          ButtonSegment(value: LanguageChoice.mine, label: Text(l10n.search_filters_my_language)),
          ButtonSegment(value: LanguageChoice.other, label: Text(l10n.search_filters_other_language)),
        ],
        selected: {filters.language},
        onSelectionChanged: (selected) => onChanged(filters.copyWith(language: selected.first)),
      ),
      if (filters.language == LanguageChoice.mine)
        Text(l10n.search_filters_my_language_hint(languageName(appSearchLanguage())),
            style: Theme.of(context).textTheme.bodySmall),
      if (filters.language == LanguageChoice.other)
        DropdownMenu<String>(
          expandedInsets: EdgeInsets.zero,
          label: Text(l10n.language),
          initialSelection: filters.otherLanguage,
          dropdownMenuEntries: searchLanguages
              .map((code) => DropdownMenuEntry(value: code, label: languageName(code)))
              .sortedByLabel(),
          onSelected: (code) => code == null ? null : onChanged(filters.copyWith(otherLanguage: code)),
        ),
    ]);
  }
}

extension on Iterable<DropdownMenuEntry<String>> {
  List<DropdownMenuEntry<String>> sortedByLabel() =>
      toList()..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
}

class _ContentFilters extends StatelessWidget {
  final SearchFilters filters;
  final ValueChanged<SearchFilters> onChanged;

  const _ContentFilters({required this.filters, required this.onChanged});

  Widget _labelled(BuildContext context, String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 6,
        children: [Text(label, style: Theme.of(context).textTheme.labelLarge), child],
      );

  Widget _contentButton(L10n l10n, ContentFilter value, ValueChanged<ContentFilter> onSelected) {
    return SegmentedButton<ContentFilter>(
      segments: [
        ButtonSegment(value: ContentFilter.include, label: Text(l10n.search_filters_include)),
        ButtonSegment(value: ContentFilter.only, label: Text(l10n.search_filters_only)),
        ButtonSegment(value: ContentFilter.exclude, label: Text(l10n.search_filters_exclude)),
      ],
      selected: {value},
      onSelectionChanged: (selected) => onSelected(selected.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 16, children: [
      _labelled(context, l10n.replies,
          _contentButton(l10n, filters.replies, (value) => onChanged(filters.copyWith(replies: value)))),
      _labelled(context, l10n.search_filters_links,
          _contentButton(l10n, filters.links, (value) => onChanged(filters.copyWith(links: value)))),
      _labelled(
        context,
        l10n.media,
        SegmentedButton<MediaFilter>(
          segments: [
            ButtonSegment(value: MediaFilter.all, label: Text(l10n.all)),
            ButtonSegment(value: MediaFilter.images, label: Text(l10n.search_filters_images)),
            ButtonSegment(value: MediaFilter.videos, label: Text(l10n.videos)),
          ],
          selected: {filters.media},
          onSelectionChanged: (selected) => onChanged(filters.copyWith(media: selected.first)),
        ),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.include_retweets),
        value: filters.reposts,
        onChanged: (value) => onChanged(filters.copyWith(reposts: value)),
      ),
    ]);
  }
}
