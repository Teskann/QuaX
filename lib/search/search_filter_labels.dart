import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:intl/intl.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/search/search_filters.dart';
import 'package:quax/ui/locale_fallback.dart';

/// The languages X can filter on, by the code `lang:` takes.
const searchLanguages = [
  'am', 'ar', 'bg', 'bn', 'ca', 'cs', 'cy', 'da', 'de', 'el', 'en', 'es', 'et', 'eu', 'fa', 'fi', 'fr', 'ga', //
  'gl', 'gu', 'he', 'hi', 'hr', 'hu', 'hy', 'id', 'is', 'it', 'ja', 'ka', 'km', 'kn', 'ko', 'lo', 'lt', 'lv', //
  'ml', 'mr', 'ms', 'my', 'ne', 'nl', 'no', 'or', 'pa', 'pl', 'ps', 'pt', 'ro', 'ru', 'si', 'sk', 'sl', 'sr', //
  'sv', 'ta', 'te', 'th', 'tl', 'tr', 'uk', 'ur', 'vi', 'zh',
];

/// The code X gives to the language of the app: Norwegian Bokmål is `no` there.
String appSearchLanguage() => switch (Intl.getCurrentLocale().split(RegExp('[-_]')).first) {
      'nb' => 'no',
      final code => code,
    };

String languageName(String code) => LocaleNamesLocalizationsDelegate.nativeLocaleNames[code] ?? code;

String activeFilterLabel(L10n l10n, ActiveFilter filter) {
  String date(DateTime value) => DateFormat.yMMMd(formattingLocale()).format(value);

  return switch (filter) {
    AnyWordsFilter(:final words) => l10n.search_filters_chip_any_words(words.join(', ')),
    NoneWordFilter(:final word) => l10n.search_filters_chip_none_word(word),
    HashtagFilter(:final tag) => '#$tag',
    FromFilter(:final account) => l10n.search_filters_chip_from(account),
    ToFilter(:final account) => l10n.search_filters_chip_to(account),
    MentionFilter(:final account) => l10n.search_filters_chip_mention(account),
    LanguageFilter(choice: LanguageChoice.mine) => l10n.search_filters_my_language,
    LanguageFilter(:final otherLanguage) => languageName(otherLanguage),
    RepliesFilter(filter: ContentFilter.only) => l10n.search_filters_chip_replies_only,
    RepliesFilter() => l10n.search_filters_chip_no_replies,
    LinksFilter(filter: ContentFilter.only) => l10n.search_filters_chip_links_only,
    LinksFilter() => l10n.search_filters_chip_no_links,
    MediaTypeFilter(media: MediaFilter.videos) => l10n.videos,
    MediaTypeFilter() => l10n.search_filters_images,
    RepostsFilter() => l10n.search_filters_chip_reposts,
    MinRepliesFilter(:final count) => l10n.search_filters_chip_min_replies(count),
    MinFavesFilter(:final count) => l10n.search_filters_chip_min_likes(count),
    MinRetweetsFilter(:final count) => l10n.search_filters_chip_min_reposts(count),
    SinceFilter(date: final value) => l10n.search_filters_chip_since(date(value)),
    UntilFilter(date: final value) => l10n.search_filters_chip_until(date(value)),
  };
}
