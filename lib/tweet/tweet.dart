import 'dart:io' show Platform;
import 'package:auto_direction/auto_direction.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_ExpandableTweetText.dart';
import 'package:quax/tweet/_card.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/ui/dates.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/rich_text.dart';
import 'package:quax/utils/translation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

class TweetTile extends StatefulWidget {
  final bool clickable;
  final String? currentUsername;
  final TweetWithCard tweet;
  final bool isPinned;
  final bool isThread;

  final bool tweetOpened;
  final bool addSeparator;

  const TweetTile(
      {super.key,
      required this.clickable,
      this.currentUsername,
      required this.tweet,
      this.isPinned = false,
      this.isThread = false,
      this.tweetOpened = false,
      this.addSeparator = true});

  @override
  TweetTileState createState() => TweetTileState();
}

class TweetTileState extends State<TweetTile> with SingleTickerProviderStateMixin {
  static final log = Logger('TweetTile');

  late final bool clickable;
  late final String? currentUsername;
  late final TweetWithCard tweet;
  late final bool isPinned;
  late final bool isThread;
  late final bool addSeparator;

  TranslationStatus _translationStatus = TranslationStatus.original;

  List<RichTextPart> _originalParts = [];
  List<RichTextPart> _displayParts = [];
  List<RichTextPart> _translatedParts = [];

  Future<void> onClickTranslate(Locale locale) async {
    // If we've already translated this text before, use those results instead of translating again
    if (_translatedParts.isNotEmpty) {
      return setState(() {
        _displayParts = _translatedParts;
        _translationStatus = TranslationStatus.translated;
      });
    }

    setState(() {
      _translationStatus = TranslationStatus.translating;
    });

    var originalText = _originalParts.map((e) => e.toString()).toList();

    var res = await TranslationAPI.translate(locale, tweet.idStr!, originalText, tweet.lang ?? "");
    if (res.success) {
      final List<RichTextPart> translatedParts = convertTextPartsToTweetEntities(res.body['result']['text']);

      // We cache the translated parts in a property in case the user swaps back and forth
      return setState(() {
        _displayParts = translatedParts;
        _translatedParts = translatedParts;
        _translationStatus = TranslationStatus.translated;
      });
    } else {
      return showTranslationError(res.errorMessage ?? 'An unknown error occurred while translating');
    }
  }

  void showTranslationError(String message) {
    setState(() {
      _translationStatus = TranslationStatus.translationFailed;
    });

    showSnackBar(context, icon: '💥', message: message);
  }

  Future<void> onClickShowOriginal() async {
    setState(() {
      _displayParts = _originalParts;
      _translationStatus = TranslationStatus.original;
    });
  }

  void onClickOpenTweet(TweetWithCard tweet) {
    Navigator.pushNamed(context, routeStatus,
        arguments: StatusScreenArguments(id: tweet.idStr!, username: tweet.user!.screenName!, tweetOpened: true));
  }

  List<RichTextPart> convertTextPartsToTweetEntities(String translatedText) {
    List<RichTextPart> translatedParts = [];
    var thing = _originalParts[0];
    if (thing.plainText != null) {
      translatedParts.add(RichTextPart(null, translatedText));
    } else {
      translatedParts.add(RichTextPart(thing.entity, null));
    }

    return translatedParts;
  }

  @override
  void initState() {
    super.initState();

    clickable = widget.clickable;
    currentUsername = widget.currentUsername;
    tweet = widget.tweet;
    isPinned = widget.isPinned;
    isThread = widget.isThread;
    addSeparator = widget.addSeparator;

    // Get the text to display from the actual tweet, i.e. the retweet if there is one, otherwise we end up with "RT @" crap in our text
    var actualTweet = tweet.retweetedStatusWithCard ?? tweet;

    // This is some super long text that I think only Twitter Blue users can write
    var noteText = tweet.retweetedStatusWithCard?.noteText ?? tweet.noteText;
    // get the longest tweet
    var tweetTextFinal = noteText ?? actualTweet.fullText ?? actualTweet.text!;

    List<RichTextPart> tweetParts = buildRichText(context, tweetTextFinal, actualTweet.entities);
    setState(() {
      _displayParts = tweetParts;
      _originalParts = tweetParts;
    });
  }

  _createFooterIconButton(IconData icon, [Color? color, double? fill, Function()? onPressed]) {
    return IconButton(
      icon: Icon(
        icon,
        fill: fill,
      ),
      color: color ?? Theme.of(context).colorScheme.primary,
      iconSize: 20,
      onPressed: onPressed,
    );
  }

  _createFooterTextButton(IconData icon, String label, [Color? color, Function()? onPressed]) {
    return TextButton.icon(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      label: Text(label, style: TextStyle(color: color, fontSize: 14)),
    );
  }

  Color? buttonsColor(BuildContext c) {
    if (Theme.of(c).textTheme.bodyMedium == null || Theme.of(c).textTheme.bodyMedium!.color == null) return null;
    final hsl = HSLColor.fromColor(Theme.of(c).textTheme.bodyMedium!.color!);
    const lightnessFactorDark = 0.5;
    const lightnessFactorLight = 4.0;
    final adjustedLightness =
        (hsl.lightness * (hsl.lightness > 0.5 ? lightnessFactorDark : lightnessFactorLight)).clamp(0.0, 1.0);
    final adjustedSaturation = (hsl.saturation * 0.2).clamp(0.0, 1.0);
    final newHsl = hsl.withLightness(adjustedLightness).withSaturation(adjustedSaturation);
    return newHsl.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context, listen: false);

    var shareBaseUrlOption = prefs.get(optionShareBaseUrl);
    var shareBaseUrl =
        shareBaseUrlOption != null && shareBaseUrlOption.isNotEmpty ? shareBaseUrlOption : 'https://x.com';

    TweetWithCard tweet = this.tweet.retweetedStatusWithCard == null ? this.tweet : this.tweet.retweetedStatusWithCard!;

    // If the user is on a profile, all the shown tweets are from that profile, so it makes no sense to hide it
    final isTweetOnSameProfile = currentUsername != null && currentUsername == tweet.user!.screenName;
    final hideAuthorInformation = !isTweetOnSameProfile && prefs.get(optionNonConfirmationBiasMode);

    var numberFormat = NumberFormat.compact();
    var theme = Theme.of(context);

    if (tweet.isTombstone ?? false) {
      return SizedBox(
        width: double.infinity,
        child: Card(
          child: Container(
              padding: const EdgeInsets.all(16),
              child: Text(tweet.text!, style: const TextStyle(fontStyle: FontStyle.italic))),
        ),
      );
    }

    Widget media = Container();
    if (tweet.extendedEntities?.media != null && tweet.extendedEntities!.media!.isNotEmpty) {
      media = TweetMedia(
        sensitive: tweet.possiblySensitive,
        media: tweet.extendedEntities!.media!,
        username: tweet.user!.screenName!,
      );
    }

    Widget retweetBanner = Container();
    Widget retweetSidebar = Container();
    if (this.tweet.retweetedStatusWithCard != null) {
      retweetBanner = _TweetTileLeading(
        icon: Icons.repeat,
        onTap: () => Navigator.pushNamed(context, routeProfile,
            arguments: ProfileScreenArguments.fromScreenName(this.tweet.user!.screenName!)),
        children: [
          TextSpan(
              text: L10n.of(context)
                  .this_tweet_user_name_retweeted(this.tweet.user!.name!, createRelativeDate(this.tweet.createdAt!)),
              style: theme.textTheme.bodySmall)
        ],
      );

      retweetSidebar = Container(color: theme.secondaryHeaderColor, width: 4);
    }

    Widget replyToTile = Container();
    var replyTo = tweet.inReplyToScreenName;
    if (replyTo != null) {
      replyToTile = _TweetTileLeading(
        onTap: () {
          var replyToId = tweet.inReplyToStatusIdStr;
          if (replyToId == null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                L10n.of(context).sorry_the_replied_tweet_could_not_be_found,
              ),
            ));
          } else {
            Navigator.pushNamed(context, routeStatus,
                arguments: StatusScreenArguments(id: replyToId, username: replyTo));
          }
        },
        icon: Icons.reply,
        children: [
          TextSpan(text: '${L10n.of(context).replying_to} ', style: theme.textTheme.bodySmall),
          TextSpan(text: '@$replyTo', style: theme.textTheme.bodySmall!.copyWith(fontWeight: FontWeight.bold)),
        ],
      );
    }

    var tweetText = tweet.fullText ?? tweet.text;
    if (tweetText == null) {
      return Text(L10n.of(context).the_tweet_did_not_contain_any_text_this_is_unexpected);
    }

    var quotedTweet = Container();

    if (tweet.isQuoteStatus ?? false) {
      if (tweet.quotedStatusWithCard != null) {
        quotedTweet = Container(
          decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.surfaceBright.withAlpha(180)),
              borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(8),
          child: TweetTile(
            clickable: true,
            tweet: tweet.quotedStatusWithCard!,
            currentUsername: currentUsername,
            addSeparator: false,
          ),
        );
      }
    }

    // Only create the tweet content if the tweet contains text
    Widget content = Container();

    if (tweet.displayTextRange![1] != 0) {
      content = Container(
          // Fill the width so both RTL and LTR text are displayed correctly
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: AutoDirection(
            text: tweetText,
            child: ExpandableTweetText(
              textSpans: displayRichText(_displayParts),
              onTap: () => !widget.tweetOpened ? onClickOpenTweet(tweet) : null,
              maxLines: 8,
            ),
          ));
    }

    var localeStr = PrefService.of(context).get<String>(optionLocale);
    final isSystemLocale = (localeStr ?? optionLocaleDefault) == optionLocaleDefault;
    if (isSystemLocale) {
      localeStr = Platform.localeName;
    }

    final splitLocale = localeStr!.split(RegExp(r'[-_]'));
    late Locale locale;
    if (splitLocale.length == 1) {
      locale = Locale(splitLocale[0]);
    } else {
      locale = Locale(splitLocale[0], splitLocale[1]);
    }

    Widget translateButton;
    switch (_translationStatus) {
      case TranslationStatus.original:
        translateButton =
            _createFooterIconButton(Icons.translate, buttonsColor(context), null, () async => onClickTranslate(locale));
        break;
      case TranslationStatus.translating:
        translateButton = const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator()),
        );
        break;
      case TranslationStatus.translationFailed:
        translateButton = _createFooterIconButton(
            Icons.translate,
            Colors.red.harmonizeWith(Theme.of(context).colorScheme.primary),
            null,
            () async => onClickTranslate(locale));
        break;
      case TranslationStatus.translated:
        translateButton = _createFooterIconButton(
            Icons.translate, Theme.of(context).colorScheme.primary, null, () async => onClickShowOriginal());
        break;
    }

    DateTime? createdAt;
    if (tweet.createdAt != null) {
      createdAt = tweet.createdAt;
    }

    return Consumer<ImportDataModel>(
        builder: (context, model, child) => Column(children: [
              Card(
                color: theme.brightness == Brightness.dark &&
                        prefs.get(optionThemeTrueBlack) &&
                        prefs.get(optionThemeTrueBlackTweetCards)
                    ? Colors.black
                    : ThemeData(
                        colorScheme:
                            ColorScheme.fromSeed(seedColor: theme.colorScheme.primary, brightness: theme.brightness),
                      ).cardColor,
                child: Row(
                  children: [
                    retweetSidebar,
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        retweetBanner,
                        replyToTile,
                        if (isPinned)
                          _TweetTileLeading(icon: Icons.push_pin, children: [
                            TextSpan(
                              text: L10n.of(context).pinned_tweet,
                              style: theme.textTheme.bodySmall,
                            )
                          ]),
                        if (isThread)
                          _TweetTileLeading(icon: Icons.forum, children: [
                            TextSpan(
                              text: L10n.of(context).thread,
                              style: theme.textTheme.bodySmall,
                            )
                          ]),
                        ListTile(
                          onTap: () {
                            // If the tweet is by the currently-viewed profile, don't allow clicks as it doesn't make sense
                            if (currentUsername != null && tweet.user!.screenName!.endsWith(currentUsername!)) {
                              return;
                            }

                            Navigator.pushNamed(context, routeProfile,
                                arguments: ProfileScreenArguments(tweet.user!.idStr, tweet.user!.screenName));
                          },
                          title: Row(children: [
                            // Username
                            if (!hideAuthorInformation)
                              Flexible(
                                child: Row(
                                  children: [
                                    Flexible(
                                        child: Text(tweet.user!.name!,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w500))),
                                    if (tweet.user!.verified ?? false) const SizedBox(width: 4),
                                    if (tweet.user!.verified ?? false)
                                      Icon(Icons.verified, size: 18, color: Theme.of(context).colorScheme.primary)
                                  ],
                                ),
                              ),
                          ]),

                          subtitle: Row(
                            mainAxisAlignment:
                                hideAuthorInformation ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
                            children: [
                              // Twitter name
                              if (!hideAuthorInformation) ...[
                                Flexible(child: Text('@${tweet.user!.screenName!}', overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 4),
                              ],
                              if (createdAt != null)
                                DefaultTextStyle(
                                    style: theme.textTheme.bodySmall!,
                                    child: Timestamp(
                                        timestamp: createdAt, absoluteTimestamp: prefs.get(optionUseAbsoluteTimestamp)))
                            ],
                          ),
                          // Profile picture
                          leading: hideAuthorInformation
                              ? const Icon(Icons.account_circle, size: 48)
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(64),
                                  child: UserAvatar(uri: tweet.user!.profileImageUrlHttps),
                                ),
                        ),
                        content,
                        media,
                        quotedTweet,
                        TweetCard(tweet: tweet, card: tweet.card),
                        Container(
                          alignment: Alignment.center,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          child: Scrollbar(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _createFooterTextButton(
                                      Icons.mode_comment_outlined,
                                      tweet.replyCount != null ? numberFormat.format(tweet.replyCount) : '',
                                      buttonsColor(context),
                                      () => onClickOpenTweet(tweet)),
                                  if (tweet.retweetCount != null && tweet.quoteCount != null)
                                    _createFooterTextButton(
                                        Icons.repeat,
                                        numberFormat.format((tweet.retweetCount! + tweet.quoteCount!)),
                                        buttonsColor(context)),
                                  if (tweet.favoriteCount != null)
                                    _createFooterTextButton(Icons.favorite_border,
                                        numberFormat.format(tweet.favoriteCount), buttonsColor(context)),
                                  const SizedBox(
                                    width: 8.0,
                                  ),
                                  Consumer<SavedTweetModel>(builder: (context, model, child) {
                                    var isSaved = model.isSaved(tweet.idStr!);
                                    if (isSaved) {
                                      return _createFooterIconButton(
                                          Icons.bookmark, Theme.of(context).colorScheme.primary, 1, () async {
                                        await model.deleteSavedTweet(tweet.idStr!);
                                        setState(() {});
                                      });
                                    } else {
                                      return _createFooterIconButton(Icons.bookmark_border, buttonsColor(context), 0,
                                          () async {
                                        await model.saveTweet(tweet.idStr!, tweet.user?.idStr, tweet.toJson());
                                        setState(() {});
                                      });
                                    }
                                  }),
                                  _createFooterIconButton(
                                    Icons.share,
                                    buttonsColor(context),
                                    null,
                                    () async {
                                      createSheetButton(title, icon, onTap) => ListTile(
                                            onTap: onTap,
                                            leading: Icon(icon),
                                            title: Text(title),
                                          );

                                      showModalBottomSheet(
                                          context: context,
                                          builder: (context) {
                                            return SafeArea(
                                                child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Consumer<SavedTweetModel>(builder: (context, model, child) {
                                                  var isSaved = model.isSaved(tweet.idStr!);
                                                  if (isSaved) {
                                                    return createSheetButton(
                                                      L10n.of(context).unsave,
                                                      Icons.bookmark_border,
                                                      () async {
                                                        await model.deleteSavedTweet(tweet.idStr!);
                                                        Navigator.pop(context);
                                                      },
                                                    );
                                                  } else {
                                                    return createSheetButton(
                                                        L10n.of(context).save, Icons.bookmark_border, () async {
                                                      await model.saveTweet(
                                                          tweet.idStr!, tweet.user?.idStr, tweet.toJson());
                                                      Navigator.pop(context);
                                                    });
                                                  }
                                                }),
                                                createSheetButton(
                                                  L10n.of(context).share_tweet_content,
                                                  Icons.share,
                                                  () async {
                                                    Share.share(tweetText);
                                                    Navigator.pop(context);
                                                  },
                                                ),
                                                createSheetButton(L10n.of(context).share_tweet_link, Icons.share,
                                                    () async {
                                                  Share.share(
                                                      '$shareBaseUrl/${tweet.user!.screenName}/status/${tweet.idStr}');
                                                  Navigator.pop(context);
                                                }),
                                                createSheetButton(
                                                    L10n.of(context).share_tweet_content_and_link, Icons.share,
                                                    () async {
                                                  Share.share(
                                                      '$tweetText\n\n$shareBaseUrl/${tweet.user!.screenName}/status/${tweet.idStr}');
                                                  Navigator.pop(context);
                                                }),
                                                const Padding(
                                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                                  child: Divider(
                                                    thickness: 1.0,
                                                  ),
                                                ),
                                                createSheetButton(
                                                  L10n.of(context).cancel,
                                                  Icons.close,
                                                  () => Navigator.pop(context),
                                                )
                                              ],
                                            ));
                                          });
                                    },
                                  ),
                                  translateButton,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ))
                  ],
                ),
              ),
              Divider(
                height: 0,
                thickness: 1,
                color: addSeparator ? theme.colorScheme.surfaceBright.withAlpha(150) : Colors.transparent,
              ),
            ]));
  }
}

class TweetHasNoContentException {
  final String? id;

  TweetHasNoContentException(this.id);

  @override
  String toString() {
    return 'The tweet has no content {id: $id}';
  }
}

class _TweetTileLeading extends StatelessWidget {
  final Function()? onTap;
  final IconData icon;
  final Iterable<InlineSpan> children;

  const _TweetTileLeading({this.onTap, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: InkWell(
        onTap: onTap,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(bottom: 0, left: 52, right: 16, top: 0),
          child: RichText(
            text: TextSpan(children: [
              WidgetSpan(
                  child: Icon(icon, size: 12, color: Theme.of(context).hintColor),
                  alignment: PlaceholderAlignment.middle),
              const WidgetSpan(child: SizedBox(width: 16)),
              ...children
            ]),
          ),
        ),
      ),
    );
  }
}

enum TranslationStatus { original, translating, translationFailed, translated }
