import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:pref/pref.dart';
import 'package:quax/settings/_tweet_actions.dart';
import 'package:quax/tweet/tweet_actions.dart';
import 'package:quax/ui/labeled_pref.dart';

class SettingsPostsFragment extends StatelessWidget {
  const SettingsPostsFragment({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.current.tweets)),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ListView(children: [
          ListTile(
            title: Text(L10n.of(context).customize_action_bar),
            trailing: parseTweetActions(PrefService.of(context).get<String>(optionTweetActions)).newActions.isEmpty
                ? null
                : const NewBadge(),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsTweetActionsFragment()),
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              pref: optionUseAbsoluteTimestamp,
              title: Text(L10n.of(context).use_absolute_timestamp),
              subtitle: Text(L10n.of(context).use_absolute_timestamp_description),
            ),
          ),
          LabeledPref(
            child: PrefCheckbox(
              title: Text(L10n.of(context).hide_sensitive_tweets),
              subtitle: Text(L10n.of(context).whether_to_hide_tweets_marked_as_sensitive),
              pref: optionTweetsHideSensitive,
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              title: Text(L10n.of(context).always_show_full_tweet_contents),
              subtitle: Text(L10n.of(context).always_show_full_tweet_contents_description),
              pref: alwaysShowFullTweetContents,
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              title: Text(L10n.of(context).activate_non_confirmation_bias_mode_label),
              pref: optionNonConfirmationBiasMode,
              subtitle: Text(L10n.of(context).activate_non_confirmation_bias_mode_description),
            ),
          ),
          LabeledPref(
            child: PrefSwitch(
              title: Text(L10n.of(context).disable_warnings_for_unrelated_posts_in_feed),
              subtitle: Text(L10n.of(context).disable_warnings_for_unrelated_posts_in_feed_description),
              pref: optionDisableWarningsForUnrelatedPostsInFeed,
            ),
          ),
        ]),
      ),
    );
  }
}
