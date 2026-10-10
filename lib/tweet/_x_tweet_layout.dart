import 'dart:math';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/ui/locale_fallback.dart';
import 'package:quax/ui/x_icons.dart';
import 'package:quax/ui/x_style.dart';

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
    final painter = TextPainter(
      text: TextSpan(text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
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

/// The row of actions under a tweet. What each action does is up to the tweet tile.
class XActionBar extends StatelessWidget {
  static const iconSize = 18.0;

  final TweetWithCard tweet;
  final NumberFormat numberFormat;
  final VoidCallback onReply;
  final VoidCallback onRepost;
  final Future<void> Function(LikedTweetModel model, bool isLiked) onToggleLike;
  final Future<void> Function(SavedTweetModel model, bool isSaved) onToggleSave;
  final VoidCallback onFileTweet;
  final VoidCallback onShare;

  const XActionBar({
    super.key,
    required this.tweet,
    required this.numberFormat,
    required this.onReply,
    required this.onRepost,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onFileTweet,
    required this.onShare,
  });

  String _count(int? count) =>
      count == null || count == 0 ? '' : numberFormat.format(count);

  @override
  Widget build(BuildContext context) {
    final retweeted = tweet.retweeted ?? false;
    final reposts = (tweet.retweetCount ?? 0) + (tweet.quoteCount ?? 0);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          ...[
            _XAction(icon: XIcons.reply, count: _count(tweet.replyCount), onTap: onReply, flushLeft: true),
            _XAction(
                icon: XIcons.repost,
                count: _count(reposts),
                color: retweeted ? XStyleColors.repost : null,
                onTap: onRepost),
            _buildLike(),
            _XAction(icon: XIcons.views, count: _count(tweet.viewCount)),
          ].map(_slot),
          _buildBookmark(),
          _XAction.share(onShare),
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
  final Color? color;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// The first action has no padding on its left, so its icon lines up with the content column
  final bool flushLeft;

  const _XAction({
    required this.icon,
    this.count = '',
    this.color,
    this.onTap,
    this.onLongPress,
    this.flushLeft = false,
  });

  factory _XAction.share(VoidCallback onTap) =>
      _XAction(icon: XIcons.share, onTap: onTap);

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
            Icon(icon, size: XActionBar.iconSize, color: tint),
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
