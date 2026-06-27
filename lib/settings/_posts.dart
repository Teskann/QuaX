import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';

class SettingsPostsFragment extends StatelessWidget {
  const SettingsPostsFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.current.tweets)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(children: [
          PrefSwitch(
            pref: optionUseAbsoluteTimestamp,
            title: Text(L10n.of(context).use_absolute_timestamp),
            subtitle: Text(L10n.of(context).use_absolute_timestamp_description),
          ),
          PrefCheckbox(
            title: Text(L10n.of(context).hide_sensitive_tweets),
            subtitle: Text(L10n.of(context).whether_to_hide_tweets_marked_as_sensitive),
            pref: optionTweetsHideSensitive,
          ),
          PrefSwitch(
            title: Text(L10n.of(context).always_show_full_tweet_contents),
            subtitle: Text(L10n.of(context).always_show_full_tweet_contents_description),
            pref: alwaysShowFullTweetContents,
          ),
          PrefSwitch(
            title: Text(L10n.of(context).activate_non_confirmation_bias_mode_label),
            pref: optionNonConfirmationBiasMode,
            subtitle: Text(L10n.of(context).activate_non_confirmation_bias_mode_description),
          ),
          PrefSwitch(
            title: Text(L10n.of(context).disable_warnings_for_unrelated_posts_in_feed),
            subtitle: Text(L10n.of(context).disable_warnings_for_unrelated_posts_in_feed_description),
            pref: optionDisableWarningsForUnrelatedPostsInFeed,
          ),
        ]),
      ),
    );
  }
}
