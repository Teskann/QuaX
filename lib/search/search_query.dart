import 'package:quax/search/search_filters.dart';

/// A search as the app shows it: the [text] left in the search bar, and the [filters] moved to the filters page.
class SearchQuery {
  final String text;
  final SearchFilters filters;

  const SearchQuery(this.text, [this.filters = SearchFilters.none]);

  /// The query sent to X, in the order of X's own advanced search.
  String compose(String appLanguage) =>
      [if (text.trim().isNotEmpty) text.trim(), ...filters.toOperators(appLanguage)].join(' ');

  /// Splits [raw] into the text to keep in the bar and the filters the filters page knows.
  /// A quoted phrase, such as a trend of several words, is what the user searches for: it stays in the text,
  /// like whatever it does not recognise, in its original order.
  static SearchQuery parse(String raw, String appLanguage) {
    final (text, filters) = _tokenize(raw).fold(
      (<String>[], SearchFilters.none),
      (acc, token) {
        final read = _readToken(token, acc.$2, appLanguage);
        return read == null ? ([...acc.$1, token], acc.$2) : (acc.$1, read);
      },
    );
    return SearchQuery(text.join(' '), filters);
  }
}

final _tokenPattern = RegExp(r'"[^"]*"|\([^()]*\)|\S+');
final _operatorPattern = RegExp(r'^(-?)([a-z_]+):(\S+)$');
final _plainWordPattern = RegExp(r'''^[^\s:"()#@-][^\s:"()]*$''');
final _accountPattern = RegExp(r'^@?(\w{1,50})$');
final _languagePattern = RegExp(r'^[a-z]{2,3}(-[a-z]{2,4})?$');
final _datePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

List<String> _tokenize(String raw) => _tokenPattern.allMatches(raw).map((match) => match.group(0)!).toList();

SearchFilters? _readToken(String token, SearchFilters filters, String appLanguage) {
  if (token.startsWith('(') && token.endsWith(')')) {
    return _readGroup(token.substring(1, token.length - 1), filters);
  }
  if (token.length > 1 && token.startsWith('-') && _plainWordPattern.hasMatch(token.substring(1))) {
    return filters.copyWith(noneWords: [...filters.noneWords, token.substring(1)]);
  }
  final operator = _operatorPattern.firstMatch(token);
  if (operator == null) {
    return null;
  }
  return _readOperator(operator.group(1) == '-', operator.group(2)!, operator.group(3)!, filters, appLanguage);
}

/// Reads `(a OR b OR …)` when every term is of the same kind: words, hashtags or accounts.
SearchFilters? _readGroup(String inner, SearchFilters filters) {
  final parts = inner.trim().split(RegExp(r'\s+'));
  final terms = [for (var i = 0; i < parts.length; i += 2) parts[i]];
  final separators = [for (var i = 1; i < parts.length; i += 2) parts[i]];
  if (parts.length.isEven || terms.length < 2 || separators.any((separator) => separator != 'OR')) {
    return null;
  }

  List<String>? allWithPrefix(String prefix) => terms.every((term) => term.startsWith(prefix))
      ? terms.map((term) => _account(term.substring(prefix.length))).nonNulls.toList()
      : null;
  List<String>? complete(List<String>? values) => values?.length == terms.length ? values : null;

  if (complete(allWithPrefix('from:')) case final accounts?) {
    return filters.copyWith(fromAccounts: [...filters.fromAccounts, ...accounts]);
  }
  if (complete(allWithPrefix('to:')) case final accounts?) {
    return filters.copyWith(toAccounts: [...filters.toAccounts, ...accounts]);
  }
  if (complete(allWithPrefix('@')) case final accounts?) {
    return filters.mentions.isEmpty ? filters.copyWith(mentions: accounts) : null;
  }
  if (terms.every((term) => term.length > 1 && term.startsWith('#') && _plainWordPattern.hasMatch(term.substring(1)))) {
    return filters.hashtags.isEmpty ? filters.copyWith(hashtags: terms.map((term) => term.substring(1)).toList()) : null;
  }
  if (terms.every(_plainWordPattern.hasMatch)) {
    return filters.anyWords.isEmpty ? filters.copyWith(anyWords: terms) : null;
  }
  return null;
}

SearchFilters? _readOperator(bool negated, String name, String value, SearchFilters filters, String appLanguage) {
  return switch ((negated, name, value)) {
    (false, 'from', _) => _account(value).let((account) => filters.copyWith(fromAccounts: [...filters.fromAccounts, account])),
    (false, 'to', _) => _account(value).let((account) => filters.copyWith(toAccounts: [...filters.toAccounts, account])),
    (false, 'lang', _) when !_languagePattern.hasMatch(value) => null,
    (false, 'lang', _) => value == appLanguage
        ? filters.copyWith(language: LanguageChoice.mine)
        : filters.copyWith(language: LanguageChoice.other, otherLanguage: value),
    (_, 'filter', 'replies') => filters.copyWith(replies: negated ? ContentFilter.exclude : ContentFilter.only),
    (_, 'filter', 'links') => filters.copyWith(links: negated ? ContentFilter.exclude : ContentFilter.only),
    (false, 'filter', 'images') => filters.copyWith(media: MediaFilter.images),
    (false, 'filter', 'videos') => filters.copyWith(media: MediaFilter.videos),
    (false, 'include', 'nativeretweets') => filters.copyWith(reposts: true),
    (false, 'min_replies', _) => _count(value).let((count) => filters.copyWith(minReplies: () => count)),
    (false, 'min_faves', _) => _count(value).let((count) => filters.copyWith(minFaves: () => count)),
    (false, 'min_retweets', _) => _count(value).let((count) => filters.copyWith(minRetweets: () => count)),
    (false, 'since', _) => _date(value).let((date) => filters.copyWith(since: () => date)),
    (false, 'until', _) => _date(value).let((date) => filters.copyWith(until: () => date)),
    _ => null,
  };
}

int? _count(String value) => RegExp(r'^\d{1,9}$').hasMatch(value) ? int.parse(value) : null;

String? _account(String value) => _accountPattern.firstMatch(value)?.group(1);

DateTime? _date(String value) {
  final match = _datePattern.firstMatch(value);
  if (match == null) {
    return null;
  }
  final date = DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
  return formatSearchDate(date) == value ? date : null;
}

extension<T extends Object> on T? {
  R? let<R>(R Function(T value) transform) {
    final value = this;
    return value == null ? null : transform(value);
  }
}
