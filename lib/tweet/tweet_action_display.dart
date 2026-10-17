import 'package:material_ui/material_ui.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/tweet_actions.dart';

IconData tweetActionIcon(TweetAction action) => switch (action) {
  TweetAction.reply => Icons.mode_comment_outlined,
  TweetAction.retweet => Icons.repeat,
  TweetAction.like => Icons.favorite_border,
  TweetAction.views => Icons.bar_chart,
  TweetAction.bookmark => Icons.bookmark_border,
  TweetAction.share => Icons.share,
  TweetAction.translate => Icons.translate,
  TweetAction.copyLink => Icons.link,
  TweetAction.copyText => Icons.content_copy,
  TweetAction.download => Icons.download,
  TweetAction.more => Icons.more_vert,
};

String tweetActionLabel(BuildContext context, TweetAction action) => switch (action) {
  TweetAction.reply => L10n.of(context).replies,
  TweetAction.retweet => L10n.of(context).reposts,
  TweetAction.like => L10n.of(context).favorites,
  TweetAction.views => L10n.of(context).views,
  TweetAction.bookmark => L10n.of(context).save,
  TweetAction.share => L10n.of(context).share,
  TweetAction.translate => L10n.of(context).translate,
  TweetAction.copyLink => L10n.of(context).copy_post_link,
  TweetAction.copyText => L10n.of(context).copy_post_text,
  TweetAction.download => L10n.of(context).download,
  TweetAction.more => L10n.of(context).more,
};
