enum ContentFilter { include, only, exclude }

enum MediaFilter { all, images, videos }

enum LanguageChoice { all, mine, other }

/// The filters of an advanced search, written in X's search syntax by [toOperators].
class SearchFilters {
  final LanguageChoice language;
  final String otherLanguage;
  final String exactPhrase;
  final List<String> anyWords;
  final List<String> noneWords;
  final List<String> hashtags;
  final List<String> fromAccounts;
  final List<String> toAccounts;
  final List<String> mentions;
  final ContentFilter replies;
  final ContentFilter links;
  final MediaFilter media;
  final bool reposts;
  final int? minReplies;
  final int? minFaves;
  final int? minRetweets;
  final DateTime? since;
  final DateTime? until;

  const SearchFilters({
    this.language = LanguageChoice.all,
    this.otherLanguage = 'en',
    this.exactPhrase = '',
    this.anyWords = const [],
    this.noneWords = const [],
    this.hashtags = const [],
    this.fromAccounts = const [],
    this.toAccounts = const [],
    this.mentions = const [],
    this.replies = ContentFilter.include,
    this.links = ContentFilter.include,
    this.media = MediaFilter.all,
    this.reposts = false,
    this.minReplies,
    this.minFaves,
    this.minRetweets,
    this.since,
    this.until,
  });

  static const none = SearchFilters();

  SearchFilters copyWith({
    LanguageChoice? language,
    String? otherLanguage,
    String? exactPhrase,
    List<String>? anyWords,
    List<String>? noneWords,
    List<String>? hashtags,
    List<String>? fromAccounts,
    List<String>? toAccounts,
    List<String>? mentions,
    ContentFilter? replies,
    ContentFilter? links,
    MediaFilter? media,
    bool? reposts,
    int? Function()? minReplies,
    int? Function()? minFaves,
    int? Function()? minRetweets,
    DateTime? Function()? since,
    DateTime? Function()? until,
  }) {
    return SearchFilters(
      language: language ?? this.language,
      otherLanguage: otherLanguage ?? this.otherLanguage,
      exactPhrase: exactPhrase ?? this.exactPhrase,
      anyWords: anyWords ?? this.anyWords,
      noneWords: noneWords ?? this.noneWords,
      hashtags: hashtags ?? this.hashtags,
      fromAccounts: fromAccounts ?? this.fromAccounts,
      toAccounts: toAccounts ?? this.toAccounts,
      mentions: mentions ?? this.mentions,
      replies: replies ?? this.replies,
      links: links ?? this.links,
      media: media ?? this.media,
      reposts: reposts ?? this.reposts,
      minReplies: minReplies != null ? minReplies() : this.minReplies,
      minFaves: minFaves != null ? minFaves() : this.minFaves,
      minRetweets: minRetweets != null ? minRetweets() : this.minRetweets,
      since: since != null ? since() : this.since,
      until: until != null ? until() : this.until,
    );
  }

  /// Adds the filters typed in the search bar to these: lists grow, single values are replaced.
  SearchFilters merge(SearchFilters typed) {
    List<String> union(List<String> a, List<String> b) => [...a, ...b.where((e) => !a.contains(e))];

    return SearchFilters(
      language: typed.language != LanguageChoice.all ? typed.language : language,
      otherLanguage: typed.language != LanguageChoice.all ? typed.otherLanguage : otherLanguage,
      exactPhrase: typed.exactPhrase.isNotEmpty ? typed.exactPhrase : exactPhrase,
      anyWords: typed.anyWords.isNotEmpty ? typed.anyWords : anyWords,
      noneWords: union(noneWords, typed.noneWords),
      hashtags: typed.hashtags.isNotEmpty ? typed.hashtags : hashtags,
      fromAccounts: union(fromAccounts, typed.fromAccounts),
      toAccounts: union(toAccounts, typed.toAccounts),
      mentions: typed.mentions.isNotEmpty ? typed.mentions : mentions,
      replies: typed.replies != ContentFilter.include ? typed.replies : replies,
      links: typed.links != ContentFilter.include ? typed.links : links,
      media: typed.media != MediaFilter.all ? typed.media : media,
      reposts: typed.reposts || reposts,
      minReplies: typed.minReplies ?? minReplies,
      minFaves: typed.minFaves ?? minFaves,
      minRetweets: typed.minRetweets ?? minRetweets,
      since: typed.since ?? since,
      until: typed.until ?? until,
    );
  }

  /// The language code X filters on, or null for every language.
  String? languageCode(String appLanguage) => switch (language) {
        LanguageChoice.all => null,
        LanguageChoice.mine => appLanguage,
        LanguageChoice.other => otherLanguage,
      };

  List<String> toOperators(String appLanguage) {
    final lang = languageCode(appLanguage);
    return [
      if (exactPhrase.isNotEmpty) '"$exactPhrase"',
      ?_anyOf(anyWords),
      ...noneWords.map((word) => '-$word'),
      ?_anyOf(hashtags.map((tag) => '#$tag').toList()),
      ?_anyOf(fromAccounts.map((account) => 'from:$account').toList()),
      ?_anyOf(toAccounts.map((account) => 'to:$account').toList()),
      ?_anyOf(mentions.map((account) => '@$account').toList()),
      if (lang != null) 'lang:$lang',
      ?_contentOperator('replies', replies),
      ?_contentOperator('links', links),
      if (media == MediaFilter.images) 'filter:images',
      if (media == MediaFilter.videos) 'filter:videos',
      if (reposts) 'include:nativeretweets',
      if (minReplies != null) 'min_replies:$minReplies',
      if (minFaves != null) 'min_faves:$minFaves',
      if (minRetweets != null) 'min_retweets:$minRetweets',
      if (since != null) 'since:${formatSearchDate(since!)}',
      if (until != null) 'until:${formatSearchDate(until!)}',
    ];
  }

  /// One entry per chip shown under the search tabs, in the order of [toOperators].
  List<ActiveFilter> get active => [
        if (exactPhrase.isNotEmpty) ExactPhraseFilter(exactPhrase),
        if (anyWords.isNotEmpty) AnyWordsFilter(anyWords),
        ...noneWords.map(NoneWordFilter.new),
        ...hashtags.map(HashtagFilter.new),
        ...fromAccounts.map(FromFilter.new),
        ...toAccounts.map(ToFilter.new),
        ...mentions.map(MentionFilter.new),
        if (language != LanguageChoice.all) LanguageFilter(language, otherLanguage),
        if (replies != ContentFilter.include) RepliesFilter(replies),
        if (links != ContentFilter.include) LinksFilter(links),
        if (media != MediaFilter.all) MediaTypeFilter(media),
        if (reposts) const RepostsFilter(),
        if (minReplies != null) MinRepliesFilter(minReplies!),
        if (minFaves != null) MinFavesFilter(minFaves!),
        if (minRetweets != null) MinRetweetsFilter(minRetweets!),
        if (since != null) SinceFilter(since!),
        if (until != null) UntilFilter(until!),
      ];

  SearchFilters without(ActiveFilter filter) => switch (filter) {
        ExactPhraseFilter() => copyWith(exactPhrase: ''),
        AnyWordsFilter() => copyWith(anyWords: const []),
        NoneWordFilter(:final word) => copyWith(noneWords: noneWords.where((e) => e != word).toList()),
        HashtagFilter(:final tag) => copyWith(hashtags: hashtags.where((e) => e != tag).toList()),
        FromFilter(:final account) => copyWith(fromAccounts: fromAccounts.where((e) => e != account).toList()),
        ToFilter(:final account) => copyWith(toAccounts: toAccounts.where((e) => e != account).toList()),
        MentionFilter(:final account) => copyWith(mentions: mentions.where((e) => e != account).toList()),
        LanguageFilter() => copyWith(language: LanguageChoice.all),
        RepliesFilter() => copyWith(replies: ContentFilter.include),
        LinksFilter() => copyWith(links: ContentFilter.include),
        MediaTypeFilter() => copyWith(media: MediaFilter.all),
        RepostsFilter() => copyWith(reposts: false),
        MinRepliesFilter() => copyWith(minReplies: () => null),
        MinFavesFilter() => copyWith(minFaves: () => null),
        MinRetweetsFilter() => copyWith(minRetweets: () => null),
        SinceFilter() => copyWith(since: () => null),
        UntilFilter() => copyWith(until: () => null),
      };

  static String? _anyOf(List<String> terms) => switch (terms.length) {
        0 => null,
        1 => terms.single,
        _ => '(${terms.join(' OR ')})',
      };

  static String? _contentOperator(String name, ContentFilter filter) => switch (filter) {
        ContentFilter.include => null,
        ContentFilter.only => 'filter:$name',
        ContentFilter.exclude => '-filter:$name',
      };
}

String formatSearchDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

sealed class ActiveFilter {
  const ActiveFilter();
}

class ExactPhraseFilter extends ActiveFilter {
  final String phrase;
  const ExactPhraseFilter(this.phrase);
}

class AnyWordsFilter extends ActiveFilter {
  final List<String> words;
  const AnyWordsFilter(this.words);
}

class NoneWordFilter extends ActiveFilter {
  final String word;
  const NoneWordFilter(this.word);
}

class HashtagFilter extends ActiveFilter {
  final String tag;
  const HashtagFilter(this.tag);
}

class FromFilter extends ActiveFilter {
  final String account;
  const FromFilter(this.account);
}

class ToFilter extends ActiveFilter {
  final String account;
  const ToFilter(this.account);
}

class MentionFilter extends ActiveFilter {
  final String account;
  const MentionFilter(this.account);
}

class LanguageFilter extends ActiveFilter {
  final LanguageChoice choice;
  final String otherLanguage;
  const LanguageFilter(this.choice, this.otherLanguage);
}

class RepliesFilter extends ActiveFilter {
  final ContentFilter filter;
  const RepliesFilter(this.filter);
}

class LinksFilter extends ActiveFilter {
  final ContentFilter filter;
  const LinksFilter(this.filter);
}

class MediaTypeFilter extends ActiveFilter {
  final MediaFilter media;
  const MediaTypeFilter(this.media);
}

class RepostsFilter extends ActiveFilter {
  const RepostsFilter();
}

class MinRepliesFilter extends ActiveFilter {
  final int count;
  const MinRepliesFilter(this.count);
}

class MinFavesFilter extends ActiveFilter {
  final int count;
  const MinFavesFilter(this.count);
}

class MinRetweetsFilter extends ActiveFilter {
  final int count;
  const MinRetweetsFilter(this.count);
}

class SinceFilter extends ActiveFilter {
  final DateTime date;
  const SinceFilter(this.date);
}

class UntilFilter extends ActiveFilter {
  final DateTime date;
  const UntilFilter(this.date);
}
