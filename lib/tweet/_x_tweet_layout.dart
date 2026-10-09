import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:quax/client/client.dart';
import 'package:quax/saved/liked_tweet_model.dart';
import 'package:quax/saved/saved_tweet_model.dart';
import 'package:quax/ui/x_style.dart';

const _avatarSize = 40.0;
const _padding = 12.0;
const _columnGap = 8.0;
const _connectorWidth = 2.0;

/// A tweet laid out like in the official X app: a flat row with the avatar on the left,
/// everything else in a column on the right, and a divider below.
class XTweetLayout extends StatelessWidget {
  final List<Widget> badges;
  final Widget avatar;
  final Widget header;
  final List<Widget> body;
  final Widget actionBar;
  final VoidCallback onTapProfile;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [...badges, _buildRow(colors)],
      ),
    );
  }

  Widget _buildRow(XStyleColors colors) {
    const centerX = _padding + _avatarSize / 2 - _connectorWidth / 2;
    const centerY = _padding + _avatarSize / 2;
    final connector = Container(width: _connectorWidth, color: colors.divider);

    return Stack(
      children: [
        if (connectTop)
          Positioned(left: centerX, top: 0, height: centerY, child: connector),
        if (connectBottom)
          Positioned(left: centerX, top: centerY, bottom: 0, child: connector),
        Padding(
          padding: const EdgeInsets.all(_padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapProfile,
                child: SizedBox(
                  width: _avatarSize,
                  height: _avatarSize,
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
class XTweetHeader extends StatelessWidget {
  final String? name;
  final String? handle;
  final bool verified;
  final String? time;

  const XTweetHeader({
    super.key,
    this.name,
    this.handle,
    this.verified = false,
    this.time,
  });

  @override
  Widget build(BuildContext context) {
    final colors = XStyleColors.of(context);
    final secondary = TextStyle(fontSize: 15, color: colors.secondaryText);
    final details = [if (handle != null) '@$handle', ?time].join(' · ');

    return Row(
      children: [
        if (name != null)
          Flexible(
            child: Text(
              name!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: colors.primaryText,
              ),
            ),
          ),
        if (verified) ...[
          const SizedBox(width: 2),
          Icon(Icons.verified, size: 16, color: XStyleColors.verified),
        ],
        Flexible(
          child: Text(
            name == null ? details : ' $details',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: secondary,
          ),
        ),
      ],
    );
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
  final Future<void> Function(LikedTweetModel model, bool isLiked) onToggleLike;
  final Future<void> Function(SavedTweetModel model, bool isSaved) onToggleSave;
  final VoidCallback onFileTweet;
  final VoidCallback onShare;
  final Widget? extra;

  const XActionBar({
    super.key,
    required this.tweet,
    required this.numberFormat,
    required this.onReply,
    required this.onToggleLike,
    required this.onToggleSave,
    required this.onFileTweet,
    required this.onShare,
    this.extra,
  });

  String _count(int? count) =>
      count == null || count == 0 ? '' : numberFormat.format(count);

  @override
  Widget build(BuildContext context) {
    final retweeted = tweet.retweeted ?? false;
    final reposts = (tweet.retweetCount ?? 0) + (tweet.quoteCount ?? 0);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _XAction(
            icon: Icons.chat_bubble_outline,
            count: _count(tweet.replyCount),
            onTap: onReply,
          ),
          _XAction(
            icon: Icons.repeat,
            count: _count(reposts),
            color: retweeted ? XStyleColors.repost : null,
          ),
          _buildLike(),
          _XAction(icon: Icons.bar_chart, count: _count(tweet.viewCount)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [_buildBookmark(), _XAction.share(onShare), ?extra],
          ),
        ],
      ),
    );
  }

  Widget _buildLike() => Consumer<LikedTweetModel>(
    builder: (context, model, child) {
      final isLiked = model.isLiked(tweet.idStr!);

      return _XAction(
        icon: isLiked ? Icons.favorite : Icons.favorite_border,
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
        icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
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

  const _XAction({
    required this.icon,
    this.count = '',
    this.color,
    this.onTap,
    this.onLongPress,
  });

  factory _XAction.share(VoidCallback onTap) =>
      _XAction(icon: Icons.ios_share, onTap: onTap);

  @override
  Widget build(BuildContext context) {
    final secondary = XStyleColors.of(context).secondaryText;
    final tint = color ?? secondary;

    return InkResponse(
      onTap: onTap,
      onLongPress: onLongPress,
      radius: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: XActionBar.iconSize, color: tint),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(count, style: TextStyle(fontSize: 13, color: tint)),
            ],
          ],
        ),
      ),
    );
  }
}
