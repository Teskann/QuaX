import 'dart:math';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/tweet/x_text_width_cache.dart';
import 'package:quax/tweet/x_web_action_screen.dart';
import 'package:quax/ui/locale_fallback.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';
import 'package:quax/utils/x_post_url.dart';

const xTweetAvatarSize = 44.0;
const _paddingLeft = 8.0;
const _paddingRight = 12.0;
const _paddingTop = 10.0;
const _paddingBottom = 4.0;
const _columnGap = 8.0;
const _connectorWidth = 2.0;

/// Where the content column starts: after the left padding, the avatar and the gap
const xTweetContentLeft = _paddingLeft + xTweetAvatarSize + _columnGap;

/// A tweet laid out like in the official X app: a flat row with the avatar on the left,
/// everything else in a column on the right, and a divider below.
class XTweetLayout extends StatelessWidget {
  final List<Widget> badges;
  final Widget avatar;
  final Widget header;
  final List<Widget> body;
  final Widget actionBar;
  final VoidCallback onTapProfile;

  /// Opens the tweet when the card is tapped where nothing has an action of its own; null when it is not clickable
  final VoidCallback? onTap;
  final bool showDivider;
  final bool connectTop;
  final bool connectBottom;

  const XTweetLayout({
    super.key,
    required this.badges,
    required this.avatar,
    required this.header,
    required this.body,
    required this.actionBar,
    required this.onTapProfile,
    this.onTap,
    this.showDivider = true,
    this.connectTop = false,
    this.connectBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: showDivider ? colors.divider : Colors.transparent,
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: colors.secondaryText.withValues(alpha: 0.1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...badges, _buildRow(colors)],
        ),
      ),
    );
  }

  Widget _buildRow(XStyleColors colors) {
    const centerX = _paddingLeft + xTweetAvatarSize / 2 - _connectorWidth / 2;
    const centerY = _paddingTop + xTweetAvatarSize / 2;
    final connector = Container(width: _connectorWidth, color: colors.divider);

    return Stack(
      children: [
        if (connectTop)
          Positioned(left: centerX, top: 0, height: centerY, child: connector),
        if (connectBottom)
          Positioned(left: centerX, top: centerY, bottom: 0, child: connector),
        Padding(
          padding: const EdgeInsets.fromLTRB(_paddingLeft, _paddingTop, _paddingRight, _paddingBottom),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapProfile,
                child: SizedBox(
                  width: xTweetAvatarSize,
                  height: xTweetAvatarSize,
                  child: avatar,
                ),
              ),
              const SizedBox(width: _columnGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapProfile,
                      child: header,
                    ),
                    ...body,
                    actionBar,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The one-line header of a tweet: name, verified badge, handle and time.
/// The name and the handle are left out when the author is hidden.
///
/// As in X, the name keeps its width first, then the time. The handle takes what is left, is cut when it does not
/// fit, and disappears when there is no room for a piece of it.
class XTweetHeader extends StatelessWidget {
  static const _badgeWidth = 18.0;
  static final _widths = TextWidthCache();

  final String? name;
  final String? handle;
  final bool verified;
  final String? time;
  final Widget? trailing;

  const XTweetHeader({
    super.key,
    this.name,
    this.handle,
    this.verified = false,
    this.time,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final info = LayoutBuilder(builder: (context, constraints) => _line(context, constraints.maxWidth));
    if (trailing == null) return info;
    return Row(children: [Expanded(child: info), const SizedBox(width: 8), trailing!]);
  }

  String get _gap => name == null ? '' : ' ';

  String? get _timeText => time == null ? null : (handle == null ? _gap : ' · ') + time!;

  double _width(BuildContext context, String? text, TextStyle style) {
    if (text == null) return 0;
    return _widths.width(text, DefaultTextStyle.of(context).style.merge(style), MediaQuery.textScalerOf(context),
        Directionality.of(context));
  }

  Widget _line(BuildContext context, double maxWidth) {
    final colors = XStyleColors.of(context);
    final nameStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.primaryText);
    final detailsStyle = TextStyle(fontSize: 16, color: colors.secondaryText);
    final badgeWidth = verified ? _badgeWidth : 0.0;
    final timeWidth = _width(context, _timeText, detailsStyle);
    final nameMax = max(0.0, maxWidth - timeWidth - badgeWidth);
    final nameWidth = min(_width(context, name, nameStyle), nameMax);
    final room = maxWidth - nameWidth - badgeWidth - timeWidth;
    final handleText = handle == null ? null : '$_gap@$handle';
    final showHandle = handleText != null && room >= _width(context, '$_gap@…', detailsStyle);

    return Row(children: [
      if (name != null)
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: nameMax),
          child: Text(name!, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: nameStyle),
        ),
      if (verified) ...[const SizedBox(width: 2), Icon(XIcons.verified, size: 16, color: XStyleColors.verified)],
      if (showHandle)
        Flexible(
            child: Text(handleText, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: detailsStyle)),
      if (_timeText != null) Text(_timeText!, maxLines: 1, softWrap: false, style: detailsStyle),
    ]);
  }
}

/// Media, quoted tweet or link card, clipped with rounded corners and an outline.
class XMediaFrame extends StatelessWidget {
  final Widget child;

  const XMediaFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: XStyleColors.of(context).divider),
      ),
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

/// The row of actions under a tweet. Replying and reposting open X's own page in QuaX, where the user acts, since QuaX
/// cannot post. What the other actions do is up to the tweet tile.
class XActionBar extends StatelessWidget {
  static const defaultIconSize = 18.0;

  final TweetWithCard tweet;
  final NumberFormat numberFormat;
  final Future<void> Function(LikedTweetModel model, bool isLiked) onToggleLike;
  final Future<void> Function(SavedTweetModel model, bool isSaved) onToggleSave;
  final VoidCallback onFileTweet;
  final VoidCallback onShare;
  final double iconSize;

  /// Spreads the actions over the whole width instead of giving the counted ones an equal slot on the left
  final bool spread;

  const XActionBar({
    super.key,
    this.iconSize = defaultIconSize,
    this.spread = false,
    required this.tweet,
    required this.numberFormat,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onFileTweet,
    required this.onShare,
  });

  String _count(int? count) => count == null || count == 0 ? '' : xCompactCount(count, numberFormat);

  void _openWebAction(BuildContext context, String uri, String title) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => XWebActionScreen(uri: uri, title: title)));

  void _reply(BuildContext context) =>
      _openWebAction(context, xReplyIntentUri(tweet.idStr!), L10n.of(context).x_web_reply);

  void _repost(BuildContext context) =>
      _openWebAction(context, xRepostIntentUri(tweet.idStr!), L10n.of(context).x_web_repost);

  @override
  Widget build(BuildContext context) {
    final retweeted = tweet.retweeted ?? false;
    final reposts = (tweet.retweetCount ?? 0) + (tweet.quoteCount ?? 0);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: spread ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
        children: [
          ...[
            _XAction(
                icon: XIcons.reply,
                count: _count(tweet.replyCount),
                iconSize: iconSize,
                onTap: () => _reply(context),
                flushLeft: true),
            _XAction(
                icon: XIcons.repost,
                count: _count(reposts),
                iconSize: iconSize,
                color: retweeted ? XStyleColors.repost : null,
                onTap: () => _repost(context)),
            _buildLike(),
            _XAction(icon: XIcons.views, count: _count(tweet.viewCount), iconSize: iconSize),
          ].map(spread ? (action) => action : _slot),
          _buildBookmark(),
          _XAction(icon: XIcons.share, iconSize: iconSize, onTap: onShare),
        ],
      ),
    );
  }

  /// The counted actions share the width evenly and start on the left of their slot, as in X
  static Widget _slot(Widget action) => Expanded(child: Align(alignment: Alignment.centerLeft, child: action));

  Widget _buildLike() => Consumer<LikedTweetModel>(
    builder: (context, model, child) {
      final isLiked = model.isLiked(tweet.idStr!);

      return _XAction(
        icon: isLiked ? XIcons.liked : XIcons.like,
        count: _count(tweet.favoriteCount),
        iconSize: iconSize,
        color: isLiked ? XStyleColors.like : null,
        onTap: () => onToggleLike(model, isLiked),
      );
    },
  );

  Widget _buildBookmark() => Consumer<SavedTweetModel>(
    builder: (context, model, child) {
      final isSaved = model.isSaved(tweet.idStr!);

      return _XAction(
        icon: isSaved ? XIcons.bookmarked : XIcons.bookmark,
        iconSize: iconSize,
        color: isSaved ? XStyleColors.of(context).accent : null,
        onTap: () => onToggleSave(model, isSaved),
        onLongPress: onFileTweet,
      );
    },
  );
}

class _XAction extends StatelessWidget {
  final IconData icon;
  final String count;
  final double iconSize;
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The first action has no padding on its left, so its icon lines up with the content column
  final bool flushLeft;

  const _XAction({
    required this.icon,
    required this.iconSize,
    this.count = '',
    this.color,
    this.onTap,
    this.onLongPress,
    this.flushLeft = false,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = XStyleColors.of(context).secondaryText;
    final tint = color ?? secondary;

    return InkResponse(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: 20,
      child: Padding(
        padding: EdgeInsets.fromLTRB(flushLeft ? 0 : 4, 6, 4, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: iconSize, color: tint),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(count,
                    maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: TextStyle(fontSize: 13, color: tint)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The translate button of the X header: a small icon where X puts its menu. [action] is null while translating.
class XTranslateButton extends StatelessWidget {
  final ({Color? color, VoidCallback onTap})? action;

  const XTranslateButton({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    if (action == null) {
      return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }
    return InkResponse(
      onTap: action.onTap,
      radius: 16,
      child: Icon(XIcons.translate, size: 16, color: action.color ?? XStyleColors.of(context).secondaryText),
    );
  }
}

/// How old a post is, written as short as X does: seconds, minutes and hours, then the day, and the year once it is
/// not the current one.
String xRelativeTime(DateTime time, DateTime now) {
  final age = now.difference(time);
  if (age.inMinutes < 1) return '${age.inSeconds.clamp(0, 59)}s';
  if (age.inHours < 1) return '${age.inMinutes}m';
  if (age.inDays < 1) return '${age.inHours}h';
  final local = time.toLocal();
  final sameYear = local.year == now.toLocal().year;
  return (sameYear ? DateFormat.MMMd(safeIntlLocale()) : DateFormat.yMMMd(safeIntlLocale())).format(local);
}

/// The time and the date of a post, as X writes them under a post that is open: "3:45 PM · Sep 5, 2026".
String xFocalTimestamp(DateTime time, {String? locale}) {
  final local = time.toLocal();
  final name = safeIntlLocale(locale);
  return '${DateFormat.jm(name).format(local)} · ${DateFormat.yMMMd(name).format(local)}';
}

const _focalPadding = 16.0;

/// The post that was opened, laid out like in the official X app: the author on top with the avatar, then the content
/// on the whole width, when it was posted and how many times it was seen, and the actions between two dividers.
class XFocalTweetLayout extends StatelessWidget {
  static const actionIconSize = 22.0;

  final List<Widget> badges;
  final Widget avatar;

  /// Null when the author is hidden
  final String? name;
  final String? handle;
  final bool verified;
  final Widget? trailing;
  final List<Widget> body;
  final DateTime? createdAt;
  final int? views;
  final Widget actionBar;
  final VoidCallback onTapProfile;

  const XFocalTweetLayout({
    super.key,
    required this.badges,
    required this.avatar,
    required this.name,
    required this.handle,
    required this.verified,
    required this.trailing,
    required this.body,
    required this.createdAt,
    required this.views,
    required this.actionBar,
    required this.onTapProfile,
  });

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 1, thickness: 1, color: XStyleColors.of(context).divider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...badges,
        Padding(padding: const EdgeInsets.fromLTRB(_focalPadding, 12, _focalPadding, 0), child: _author(context)),
        Padding(
          padding: const EdgeInsets.fromLTRB(_focalPadding, 12, _focalPadding, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: body),
        ),
        _details(context),
        divider,
        Padding(padding: const EdgeInsets.symmetric(horizontal: _focalPadding), child: actionBar),
        divider,
      ],
    );
  }

  Widget _author(BuildContext context) {
    final colors = XStyleColors.of(context);
    final trailing = this.trailing;
    return Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTapProfile,
          child: SizedBox(width: xTweetAvatarSize, height: xTweetAvatarSize, child: avatar),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTapProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null) _name(colors),
                if (handle != null)
                  Text('@$handle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15, color: colors.secondaryText)),
              ],
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  Widget _name(XStyleColors colors) => Row(children: [
        Flexible(
          child: Text(name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.primaryText)),
        ),
        if (verified) ...[const SizedBox(width: 2), Icon(XIcons.verified, size: 16, color: XStyleColors.verified)],
      ]);

  Widget _details(BuildContext context) {
    final colors = XStyleColors.of(context);
    final createdAt = this.createdAt;
    final views = this.views;
    if (createdAt == null && views == null) return const SizedBox(height: 12);
    final count = views == null ? null : NumberFormat.compact(locale: safeIntlLocale()).format(views);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_focalPadding, 12, _focalPadding, 12),
      child: Text.rich(
        TextSpan(style: TextStyle(fontSize: 15, color: colors.secondaryText), children: [
          if (createdAt != null) TextSpan(text: xFocalTimestamp(createdAt)),
          if (createdAt != null && count != null) const TextSpan(text: ' · '),
          if (count != null) ...[
            TextSpan(text: count, style: TextStyle(fontWeight: FontWeight.w700, color: colors.primaryText)),
            TextSpan(text: ' ${L10n.of(context).views}'),
          ],
        ]),
      ),
    );
  }
}

/// How X writes a count: in full under a thousand, then with at most one decimal below ten of a unit and none above
/// (4.1K, 28K, 542K, 1.2M), cut rather than rounded so a count is never shown higher than it is. [compact] gives the
/// unit and the decimal sign of the locale.
String xCompactCount(int count, NumberFormat compact) {
  if (count < 1000) return '$count';
  final unit = count < 1000000 ? 1000 : (count < 1000000000 ? 1000000 : 1000000000);
  final step = count < unit * 10 ? unit ~/ 10 : unit;
  return compact.format(count - count % step);
}
