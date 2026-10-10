import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:auto_direction/auto_direction.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:quax/client/client.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/profile/profile.dart';
import 'package:quax/saved/folder_picker.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/tweet/_like_button.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/status.dart';
import 'package:quax/tweet/_expandable_tweet_text.dart';
import 'package:quax/tweet/_card.dart';
import 'package:quax/tweet/_media.dart';
import 'package:quax/tweet/_x_tweet_layout.dart';
import 'package:quax/tweet/unavailable_tweet.dart';
import 'package:quax/article/article.dart';
import 'package:quax/ui/dates.dart';
import 'package:quax/ui/errors.dart';
import 'package:quax/ui/locale_fallback.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/user.dart';
import 'package:quax/utils/rich_text.dart';
import 'package:quax/utils/urls.dart';
import 'package:quax/utils/translation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:pref/pref.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

/// Footer buttons should feel flat: no ripple and no pressed/hover background.
const footerButtonStyle = ButtonStyle(
  overlayColor: WidgetStatePropertyAll(Colors.transparent),
  splashFactory: NoSplash.splashFactory,
);

class TweetTile extends StatefulWidget {
  final bool clickable;
  final String? currentUsername;
  final TweetWithCard tweet;
  final bool isPinned;
  final bool isThread;
  final bool isQuotedTweet;

  // Whether to draw a connector line above/below the avatar, linking this tile to the
  // previous/next tweet of the same thread.
  final bool threadConnectTop;
  final bool threadConnectBottom;

  final bool tweetOpened;
  final bool addSeparator;
  final bool isBirdwatchQuote;
  final int initialMediaIndex;

  /// Whether this is the post whose conversation is open, which the X design lays out in its own way
  final bool isFocal;

  const TweetTile(
      {super.key,
      required this.clickable,
      this.currentUsername,
      required this.tweet,
      this.isPinned = false,
      this.isThread = false,
      this.tweetOpened = false,
      this.addSeparator = true,
      this.isQuotedTweet = false,
      this.isBirdwatchQuote = false,
      this.threadConnectTop = false,
      this.threadConnectBottom = false,
      this.initialMediaIndex = 0,
      this.isFocal = false});

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
  late final bool isQuotedTweet;
  late final bool addSeparator;
  late final bool isBirdwatchQuote;

  TranslationStatus _translationStatus = TranslationStatus.original;

  List<RichTextPart> _originalParts = [];
  List<RichTextPart> _displayParts = [];
  List<RichTextPart> _translatedParts = [];

  bool _isInitialized = false;

  final GlobalKey _globalKey = GlobalKey(); // needed for "share tweet as image"

  @override
  void initState() {
    super.initState();

    clickable = widget.clickable;
    currentUsername = widget.currentUsername;
    tweet = widget.tweet;
    isPinned = widget.isPinned;
    isThread = widget.isThread;
    isQuotedTweet = widget.isQuotedTweet;
    addSeparator = widget.addSeparator;
    isBirdwatchQuote = widget.isBirdwatchQuote;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialized) {
      _initializeTweetParts();
      _isInitialized = true;
    }
  }

  void _initializeTweetParts() {
    // An unavailable post is drawn as such, often without any text to prepare
    if (tweet.isTombstone ?? false) {
      return;
    }

    // Get the text to display from the actual tweet, i.e. the retweet if there is one, otherwise we end up with "RT @" crap in our text
    var actualTweet = tweet.retweetedStatusWithCard ?? tweet;
    // get the longest tweet between legacy (still used most of the time) and noteText (mostly ny premium users?)
    var tweetTextFinal = actualTweet.noteText ?? actualTweet.fullText ?? actualTweet.text!;
    var entitiesFinal = actualTweet.noteEntities ?? actualTweet.entities;

    List<RichTextPart> tweetParts = buildRichText(context, tweetTextFinal, entitiesFinal, hideCardUrls: actualTweet.card != null);
    setState(() {
      _displayParts = tweetParts;
      _originalParts = tweetParts;
    });
  }

  Future<void> onClickTranslate(BuildContext context, Locale locale) async {
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
      if (!context.mounted) return;
      final List<RichTextPart> translatedParts =
        buildRichText(context, res.body['result']['text'], res.body['result']['entities']);

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
        arguments: StatusScreenArguments(
            id: tweet.idStr!,
            username: tweet.user!.screenName!,
            tweetOpened: true,
            initialTweet: tweet));
  }

  IconButton _createFooterIconButton(IconData icon, [Color? color, double? fill, Function()? onPressed]) {
    return IconButton(
      icon: Icon(
        icon,
        fill: fill,
      ),
      color: color ?? Theme.of(context).colorScheme.primary,
      iconSize: 20,
      onPressed: onPressed,
      style: footerButtonStyle,
    );
  }

  /// Shows a one-time hint teaching the long-press-to-file gesture after the first save.
  void _maybeShowFolderHint(BuildContext context) {
    var prefs = PrefService.of(context, listen: false);
    if (prefs.get<bool>(optionSavedFolderHintShown) ?? false) {
      return;
    }

    prefs.set(optionSavedFolderHintShown, true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.of(context).long_press_folder_hint)));
  }

  /// Shows a one-time notice, on the very first like, that likes never leave the device.
  void _maybeShowLikeToast(BuildContext context) {
    var prefs = PrefService.of(context, listen: false);
    if (prefs.get<bool>(optionLikedFirstToastShown) ?? false) {
      return;
    }

    prefs.set(optionLikedFirstToastShown, true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L10n.of(context).likes_stay_on_device_notice),
      duration: const Duration(seconds: 6),
    ));
  }

  TextButton _createFooterTextButton(IconData icon, String label, [Color? color, Function()? onPressed]) {
    return TextButton.icon(
      icon: Icon(icon, size: 20, color: color),
      onPressed: onPressed,
      label: Text(label, style: TextStyle(color: color, fontSize: 14)),
      style: footerButtonStyle,
    );
  }

  /// The color and the action of the translate button, or null while the translation is loading
  ({Color? color, VoidCallback onTap})? _translateAction(Locale locale, {Color? idleColor}) {
    final primary = Theme.of(context).colorScheme.primary;
    return switch (_translationStatus) {
      TranslationStatus.original => (color: idleColor, onTap: () => onClickTranslate(context, locale)),
      TranslationStatus.translating => null,
      TranslationStatus.translationFailed => (
          color: Colors.red.harmonizeWith(primary),
          onTap: () => onClickTranslate(context, locale)
        ),
      TranslationStatus.translated => (color: primary, onTap: () => onClickShowOriginal()),
    };
  }

  Widget _buildTranslateButton(Locale locale) {
    final action = _translateAction(locale, idleColor: buttonsColor(context));
    if (action == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator()),
      );
    }
    return _createFooterIconButton(Icons.translate, action.color, null, () async => action.onTap());
  }

  Future<void> _toggleLike(LikedTweetModel model, TweetWithCard tweet, bool isLiked) async {
    if (isLiked) {
      await model.unlikeTweet(tweet.idStr!);
    } else {
      await model.likeTweet(tweet.idStr!, tweet.user?.idStr, tweet.toJson());
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    if (!isLiked) {
      _maybeShowLikeToast(context);
    }
  }

  Future<void> _toggleSave(SavedTweetModel model, TweetWithCard tweet, bool isSaved) async {
    if (isSaved) {
      await model.deleteSavedTweet(tweet.idStr!);
    } else {
      await model.saveTweet(tweet.idStr!, tweet.user?.idStr, tweet.toJson());
    }
    if (!mounted) {
      return;
    }
    setState(() {});
    if (!isSaved) {
      _maybeShowFolderHint(context);
    }
  }

  Future<void> _fileTweet(TweetWithCard tweet) async {
    await showSaveToFolderSheet(context, tweetId: tweet.idStr!, userId: tweet.user?.idStr, content: tweet.toJson());
    if (mounted) {
      setState(() {});
    }
  }

  void _showShareSheet(TweetWithCard tweet, String tweetText, String shareBaseUrl, bool isArticle) {
    showModalBottomSheet(
        context: context,
        builder: (sheetContext) => SafeArea(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _shareSheetEntries(sheetContext, tweet, tweetText, shareBaseUrl, isArticle),
        )));
  }

  List<Widget> _shareSheetEntries(
      BuildContext sheetContext, TweetWithCard tweet, String tweetText, String shareBaseUrl, bool isArticle) {
    final l10n = L10n.of(sheetContext);
    final link = '$shareBaseUrl/${tweet.user!.screenName}/status/${tweet.idStr}';
    createSheetButton(title, icon, onTap) => ListTile(
          onTap: onTap,
          leading: Icon(icon),
          title: Text(title),
        );

    return [
      if (!isArticle)
        createSheetButton(l10n.share_tweet_content, Icons.text_snippet, () async {
          SharePlus.instance.share(ShareParams(text: tweetText));
          Navigator.pop(sheetContext);
        }),
      createSheetButton(isArticle ? l10n.share_article_link : l10n.share_tweet_link, Icons.link, () async {
        SharePlus.instance.share(ShareParams(text: link));
        Navigator.pop(sheetContext);
      }),
      if (!isArticle)
        createSheetButton(l10n.share_tweet_content_and_link, Icons.add_link, () async {
          SharePlus.instance.share(ShareParams(text: '$tweetText\n\n$link'));
          Navigator.pop(sheetContext);
        }),
      createSheetButton(isArticle ? l10n.share_article_as_image : l10n.share_tweet_as_image, Icons.screenshot,
          () async {
        Uint8List? imgBytes = await captureWidget();
        if (imgBytes != null) {
          SharePlus.instance.share(ShareParams(files: [XFile.fromData(imgBytes, mimeType: 'image/png')]));
        }
        if (sheetContext.mounted) {
          Navigator.pop(sheetContext);
        }
      }),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(
          thickness: 1.0,
        ),
      ),
      createSheetButton(l10n.cancel, Icons.close, () => Navigator.pop(sheetContext)),
    ];
  }

  Widget _buildFooterBar(TweetWithCard tweet, String tweetText, String shareBaseUrl, Locale locale, NumberFormat numberFormat, {bool isArticle = false}) {
    return Container(
      alignment: Alignment.center,
      margin: isArticle ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 8),
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
              Consumer<LikedTweetModel>(builder: (context, likedModel, child) {
                var isLiked = likedModel.isLiked(tweet.idStr!);
                var label = tweet.favoriteCount != null ? numberFormat.format(tweet.favoriteCount) : '';

                return LikeButton(
                  isLiked: isLiked,
                  label: label,
                  color: isLiked ? Theme.of(context).colorScheme.primary : buttonsColor(context),
                  onPressed: () => _toggleLike(likedModel, tweet, isLiked),
                );
              }),
              if (tweet.viewCount != null)
                _createFooterTextButton(
                    Icons.bar_chart,
                    numberFormat.format(tweet.viewCount),
                    buttonsColor(context)),
              const SizedBox(
                width: 8.0,
              ),
              Consumer<SavedTweetModel>(builder: (context, model, child) {
                var isSaved = model.isSaved(tweet.idStr!);
                var button = isSaved
                    ? _createFooterIconButton(
                        Icons.bookmark, Theme.of(context).colorScheme.primary, 1, () => _toggleSave(model, tweet, true))
                    : _createFooterIconButton(
                        Icons.bookmark_border, buttonsColor(context), 0, () => _toggleSave(model, tweet, false));

                return GestureDetector(
                  onLongPress: () => _fileTweet(tweet),
                  child: button,
                );
              }),
              _createFooterIconButton(Icons.share, buttonsColor(context), null,
                  () async => _showShareSheet(tweet, tweetText, shareBaseUrl, isArticle)),
              if (!isArticle) _buildTranslateButton(locale),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXActionBar(TweetWithCard tweet, String tweetText, String shareBaseUrl, Locale locale,
      NumberFormat numberFormat, {bool isArticle = false}) {
    return XActionBar(
      iconSize: widget.isFocal ? XFocalTweetLayout.actionIconSize : XActionBar.defaultIconSize,
      spread: widget.isFocal,
      tweet: tweet,
      numberFormat: numberFormat,
      onToggleLike: (model, isLiked) => _toggleLike(model, tweet, isLiked),
      onToggleSave: (model, isSaved) => _toggleSave(model, tweet, isSaved),
      onFileTweet: () => _fileTweet(tweet),
      onShare: () => _showShareSheet(tweet, tweetText, shareBaseUrl, isArticle),
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

  Widget _buildUnavailableQuote(TweetWithCard tweet) {
    final permalink = Uri.tryParse(tweet.quotedStatusPermalink?.expanded ?? '');
    final screenName = permalink == null ? null : parsePostLink(permalink)?.screenName;
    return UnavailableTweetCard(
      reason: tweet.quotedStatusWithCard?.text,
      screenName: screenName,
      id: tweet.quotedStatusIdStr,
      margin: EdgeInsets.zero,
    );
  }

  Future<Uint8List?> captureWidget() async {
    if (_globalKey.currentContext == null) {
      return null;
    }
    final RenderRepaintBoundary boundary = _globalKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return null;
    }
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    return pngBytes;
  }

  TextStyle _xTextStyle(BuildContext context) => TextStyle(
      fontSize: widget.isFocal ? 17 : 16,
      height: widget.isFocal ? 1.35 : 1.3,
      color: XStyleColors.of(context).primaryText);

  String? _formatTime(DateTime? time, bool absolute, {bool compact = false}) {
    if (time == null) {
      return null;
    }
    if (absolute) {
      return absoluteDateFormat.format(time.toLocal());
    }
    return compact ? xRelativeTime(time, DateTime.now()) : createRelativeDate(time);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = PrefService.of(context, listen: false);

    var shareBaseUrlOption = prefs.get(optionShareBaseUrl);
    var shareBaseUrl =
        shareBaseUrlOption != null && shareBaseUrlOption.isNotEmpty ? shareBaseUrlOption : 'https://x.com';

    TweetWithCard tweet = this.tweet.retweetedStatusWithCard == null ? this.tweet : this.tweet.retweetedStatusWithCard!;

    // If the user is on a profile, all the shown tweets are from that profile, so it makes no sense to hide it
    final isTweetOnSameProfile =
        currentUsername != null && tweet.user != null && currentUsername == tweet.user!.screenName;
    final hideAuthorInformation = !isTweetOnSameProfile && prefs.get(optionNonConfirmationBiasMode);

    var numberFormat = NumberFormat.compact(locale: safeIntlLocale());
    var theme = Theme.of(context);
    final xStyle = isXStyle(context);
    final smallStyle = theme.textTheme.bodySmall!.copyWith(color: xStyle ? XStyleColors.of(context).secondaryText : null);

    if (tweet.isTombstone ?? false) {
      return UnavailableTweetCard(reason: tweet.text);
    }

    Widget media = Container();
    if (tweet.extendedEntities?.media != null && tweet.extendedEntities!.media!.isNotEmpty) {
      media = TweetMedia(
        sensitive: tweet.possiblySensitive,
        media: tweet.extendedEntities!.media!,
        username: tweet.user!.screenName!,
        initialMediaIndex: widget.initialMediaIndex,
        tweetId: tweet.idStr,
      );
      if (xStyle) {
        media = XMediaFrame(child: media);
      }
    }

    Widget retweetBanner = Container();
    Widget retweetSidebar = Container();
    if (this.tweet.retweetedStatusWithCard != null) {
      retweetBanner = _TweetTileLeading(
        icon: xStyle ? XIcons.retweetBanner : Icons.repeat,
        onTap: () => Navigator.pushNamed(context, routeProfile,
            arguments: ProfileScreenArguments.fromScreenName(this.tweet.user!.screenName!, null)),
        children: [
          xStyle
              ? TextSpan(
                  text: L10n.of(context).x_user_reposted(this.tweet.user!.name!),
                  style: smallStyle.copyWith(fontSize: 13, fontWeight: FontWeight.w700))
              : TextSpan(
                  text: L10n.of(context).this_tweet_user_name_retweeted(
                      this.tweet.user!.name!, createRelativeDate(this.tweet.createdAt!)),
                  style: smallStyle)
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
          TextSpan(text: '${L10n.of(context).replying_to} ', style: smallStyle),
          TextSpan(text: '@$replyTo', style: smallStyle.copyWith(fontWeight: FontWeight.bold)),
        ],
      );
    }

    var tweetText = tweet.fullText ?? tweet.text;
    if (tweetText == null) {
      return Text(L10n.of(context).the_tweet_did_not_contain_any_text_this_is_unexpected);
    }

    if (isBirdwatchQuote) {
      return Card(
          child: Container(
            // Fill the width so both RTL and LTR text are displayed correctly
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                  children: [
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(bottom: 0, left: 24, right: 16, top: 0),
                      child: RichText(
                        text: TextSpan(children: [
                          WidgetSpan(
                              child: Icon(Icons.group_rounded, size: 16, color: Theme
                                  .of(context)
                                  .hintColor),
                              alignment: PlaceholderAlignment.middle
                          ),
                          const WidgetSpan(child: SizedBox(width: 16)),
                          TextSpan(
                            text: L10n
                                .of(context)
                                .community_notes_header,
                            style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.titleSmall?.color),
                          )
                        ]),
                      ),
                    ),
                    SizedBox(height: 8),
                    AutoDirection(
                        text: tweetText,
                        child: SelectableText.rich(
                          TextSpan(children: [
                            ..._displayParts.map((e) {
                              if (e.plainText != null) {
                                return TextSpan(text: e.plainText);
                              }
                              else {
                                return e.entity!;
                              }
                            })
                          ]),
                        )
                    ),
                  ]
              )
          )
      );
    }

    var birdwatchQuoted = Container();
    if (tweet.birdwatchQuotedStatus != null) {
      birdwatchQuoted = Container(
        margin: const EdgeInsets.all(8),
        child: TweetTile(
          clickable: false,
          tweet: tweet.birdwatchQuotedStatus!,
          isBirdwatchQuote: true,
        ),
      );
    }

    Widget quotedTweet = Container();

    // don't display a nested quoted tweet if we are already building a quoted tweet
    if (!isQuotedTweet && (tweet.isQuoteStatus ?? false)) {
      final quoted = tweet.quotedStatusWithCard;
      final Widget quotedContent = quoted != null && !(quoted.isTombstone ?? false)
          ? TweetTile(
              clickable: true,
              tweet: quoted,
              currentUsername: currentUsername,
              addSeparator: false,
              isQuotedTweet: true,
            )
          : _buildUnavailableQuote(tweet);
      quotedTweet = xStyle
          ? XMediaFrame(child: quotedContent)
          : Container(
              decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.surfaceBright.withAlpha(180)),
                  borderRadius: BorderRadius.circular(8)),
              margin: const EdgeInsets.all(8),
              child: quotedContent,
            );
    }

    // Only create the tweet content if the tweet contains text
    Widget content = Container();

    if (tweet.displayTextRange![1] != 0) {
      content = Container(
          // Fill the width so both RTL and LTR text are displayed correctly
          width: double.infinity,
          padding: xStyle ? const EdgeInsets.only(top: 2) : const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: AutoDirection(
            text: tweetText,
            child: DefaultTextStyle.merge(
              style: xStyle ? _xTextStyle(context) : null,
              child: ExpandableTweetText(
                textSpans: displayRichText(_displayParts),
                onTap: () => !widget.tweetOpened ? onClickOpenTweet(tweet) : null,
                maxLines: PrefService.of(context).get(alwaysShowFullTweetContents) ? null : 8,
              ),
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

    final buildFooter = xStyle ? _buildXActionBar : _buildFooterBar;
    final footerBar = buildFooter(tweet, tweetText, shareBaseUrl, locale, numberFormat, isArticle: tweet.article != null);

    Widget article = Container();
    if (tweet.article != null) {
      article = ArticleWidget(
        article: tweet.article!,
        expand: widget.tweetOpened,
        onTap: () => onClickOpenTweet(tweet),
        bottomBar: widget.tweetOpened ? footerBar : null,
      );
    }

    DateTime? createdAt;
    if (tweet.createdAt != null) {
      createdAt = tweet.createdAt;
    }

    final avatarSize = xStyle ? xTweetAvatarSize : 48.0;
    final avatar = hideAuthorInformation
        ? Icon(Icons.account_circle, size: avatarSize)
        : ClipRRect(
            borderRadius: BorderRadius.circular(64),
            child: UserAvatar(uri: tweet.user!.profileImageUrlHttps, size: avatarSize),
          );

    void onTapProfile() {
      // If the tweet is by the currently-viewed profile, don't allow clicks as it doesn't make sense
      if (currentUsername != null && tweet.user!.screenName!.endsWith(currentUsername!)) {
        return;
      }
      Navigator.pushNamed(context, routeProfile,
          arguments: ProfileScreenArguments(tweet.user!.idStr, tweet.user!.screenName, null));
    }

    final titleRow = Row(children: [
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
                Icon(verifiedIcon(context), size: 18, color: verifiedColor(context))
            ],
          ),
        ),
    ]);

    final subtitleRow = Row(
      mainAxisAlignment: hideAuthorInformation ? MainAxisAlignment.end : MainAxisAlignment.spaceBetween,
      children: [
        // Twitter name
        if (!hideAuthorInformation) ...[
          Flexible(child: Text('@${tweet.user!.screenName!}', overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4),
        ],
        if (createdAt != null)
          DefaultTextStyle(
              style: theme.textTheme.bodySmall!,
              child:
                  Timestamp(timestamp: createdAt, absoluteTimestamp: prefs.get(optionUseAbsoluteTimestamp)))
      ],
    );

    final headerTile = ListTile(
      onTap: onTapProfile,
      title: titleRow,
      subtitle: subtitleRow,
      // Profile picture
      leading: avatar,
    );

    final pinnedBadge = isPinned
        ? _TweetTileLeading(icon: xStyle ? XIcons.pinned : Icons.push_pin, children: [
            TextSpan(text: L10n.of(context).pinned_tweet, style: smallStyle)
          ])
        : null;
    final threadBadge = isThread
        ? _TweetTileLeading(icon: Icons.forum, children: [
            TextSpan(text: L10n.of(context).thread, style: smallStyle)
          ])
        : null;

    final tweetCard = TweetCard(tweet: tweet, card: tweet.card);
    final contentChildren = <Widget>[
      if (tweet.article == null) content,
      if (tweet.isSubscriberPreview) _SubscriberPreviewNotice(screenName: tweet.user?.screenName ?? ''),
      media,
      quotedTweet,
      xStyle && tweet.card != null ? XMediaFrame(child: tweetCard) : tweetCard,
      birdwatchQuoted,
      article,
    ];
    final bodyChildren = [...contentChildren, footerBar];

    if (xStyle && widget.isFocal) {
      return Consumer<ImportDataModel>(
          builder: (context, model, child) => RepaintBoundary(
              key: _globalKey,
              child: XFocalTweetLayout(
                badges: [retweetBanner, replyToTile, ?pinnedBadge, ?threadBadge],
                avatar: avatar,
                name: hideAuthorInformation ? null : tweet.user!.name,
                handle: hideAuthorInformation ? null : tweet.user!.screenName,
                verified: !hideAuthorInformation && (tweet.user!.verified ?? false),
                trailing: tweet.article == null ? XTranslateButton(action: _translateAction(locale)) : null,
                body: contentChildren,
                createdAt: createdAt,
                views: tweet.viewCount,
                actionBar: footerBar,
                onTapProfile: onTapProfile,
              )));
    }

    if (xStyle) {
      return Consumer<ImportDataModel>(
          builder: (context, model, child) => RepaintBoundary(
              key: _globalKey,
              child: XTweetLayout(
                badges: [retweetBanner, if (!widget.threadConnectTop) replyToTile, ?pinnedBadge, ?threadBadge],
                avatar: avatar,
                header: XTweetHeader(
                  name: hideAuthorInformation ? null : tweet.user!.name,
                  handle: hideAuthorInformation ? null : tweet.user!.screenName,
                  verified: !hideAuthorInformation && (tweet.user!.verified ?? false),
                  time: _formatTime(createdAt, prefs.get(optionUseAbsoluteTimestamp), compact: true),
                  trailing: tweet.article == null ? XTranslateButton(action: _translateAction(locale)) : null,
                ),
                body: contentChildren,
                actionBar: footerBar,
                onTapProfile: onTapProfile,
                onTap: clickable && !widget.tweetOpened ? () => onClickOpenTweet(tweet) : null,
                showDivider: addSeparator && !widget.threadConnectBottom,
                connectTop: widget.threadConnectTop,
                connectBottom: widget.threadConnectBottom,
              )));
    }

    final isThreadTile = widget.threadConnectTop || widget.threadConnectBottom;

    if (isThreadTile) {
      return Consumer<ImportDataModel>(
          builder: (context, model, child) => RepaintBoundary(
              key: _globalKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  retweetBanner,
                  if (!widget.threadConnectTop) replyToTile,
                  ?pinnedBadge,
                  ?threadBadge,
                  _buildThreadBody(
                      theme,
                      avatar,
                      InkWell(
                        onTap: onTapProfile,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DefaultTextStyle.merge(style: theme.textTheme.bodyLarge, child: titleRow),
                              DefaultTextStyle.merge(style: theme.textTheme.bodyMedium, child: subtitleRow),
                            ],
                          ),
                        ),
                      ),
                      bodyChildren,
                      indentBody: widget.threadConnectBottom,
                      onTapProfile: onTapProfile),
                ],
              )));
    }

    return Consumer<ImportDataModel>(
        builder: (context, model, child) => RepaintBoundary(
            key: _globalKey,
            child: Column(children: [
              Card(
                color: tweetCardColor(context),
                child: Row(
                  children: [
                    retweetSidebar,
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        retweetBanner,
                        replyToTile,
                        ?pinnedBadge,
                        ?threadBadge,
                        headerTile,
                        ...bodyChildren,
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
            ])));
  }

  Widget _buildThreadBody(ThemeData theme, Widget avatar, Widget header, List<Widget> bodyChildren,
      {required bool indentBody, required VoidCallback onTapProfile}) {
    const railLeft = 16.0;
    const topGap = 10.0;
    const avatarSize = 48.0;
    const lineWidth = 2.0;
    const lineX = railLeft + avatarSize / 2 - lineWidth / 2;
    const avatarCenterY = topGap + avatarSize / 2;
    const bodyIndent = railLeft + avatarSize;
    final lineColor = theme.colorScheme.outlineVariant;
    Widget lineSeg() => Container(width: lineWidth, color: lineColor);

    return Stack(
      children: [
        if (widget.threadConnectTop)
          Positioned(left: lineX, top: 0, height: avatarCenterY, child: lineSeg()),
        if (widget.threadConnectBottom)
          Positioned(left: lineX, top: avatarCenterY, bottom: 0, child: lineSeg()),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: railLeft),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: topGap),
                    SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: GestureDetector(
                          behavior: HitTestBehavior.opaque, onTap: onTapProfile, child: avatar),
                    ),
                  ],
                ),
                Expanded(child: header),
              ],
            ),
            if (indentBody)
              Padding(
                padding: const EdgeInsets.only(left: bodyIndent),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: bodyChildren),
              ),
            if (!indentBody) ...bodyChildren,
          ],
        ),
      ],
    );
  }
}

Color? tweetCardColor(BuildContext context) {
  final theme = Theme.of(context);
  final prefs = PrefService.of(context, listen: false);
  final trueBlack = theme.brightness == Brightness.dark &&
      prefs.get(optionThemeTrueBlack) &&
      prefs.get(optionThemeTrueBlackTweetCards);
  return trueBlack
      ? Colors.black
      : ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: theme.colorScheme.primary, brightness: theme.brightness),
        ).cardColor;
}

class TweetHasNoContentException {
  final String? id;

  TweetHasNoContentException(this.id);

  @override
  String toString() {
    return 'The tweet has no content {id: $id}';
  }
}

/// Says why a post reserved to the subscribers of its author stops short
class _SubscriberPreviewNotice extends StatelessWidget {
  final String screenName;

  const _SubscriberPreviewNotice({required this.screenName});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Row(children: [
        Icon(Icons.lock_outline, size: 14, color: style?.color),
        const SizedBox(width: 8),
        Flexible(child: Text(L10n.of(context).subscribers_only_post(screenName), style: style)),
      ]),
    );
  }
}

class _TweetTileLeading extends StatelessWidget {
  final Function()? onTap;
  final IconData icon;
  final Iterable<InlineSpan> children;

  const _TweetTileLeading({this.onTap, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    if (isXStyle(context)) {
      return _buildX(context);
    }

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

  /// A single line whose icon ends 4px before the content column of the tweet, which starts at 60
  Widget _buildX(BuildContext context) {
    const iconSize = 16.0;
    const gap = 4.0;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: xTweetContentLeft - gap - iconSize, right: 16),
          child: Row(children: [
            Icon(icon, size: iconSize, color: XStyleColors.of(context).secondaryText),
            const SizedBox(width: gap),
            Flexible(child: Text.rich(TextSpan(children: children.toList()), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      ),
    );
  }
}

enum TranslationStatus { original, translating, translationFailed, translated }