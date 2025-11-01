import 'package:flutter/material.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/group/group_model.dart';

void showFeedSettings(BuildContext context, GroupModel model) {
  showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.of(context).pop();
                  }),
              title: Text(
                L10n.of(context).filters,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Container(
                alignment: Alignment.centerLeft,
                margin: const EdgeInsets.only(bottom: 8, top: 16, left: 16, right: 16),
                child: Text(
                  L10n.of(context).note_due_to_a_twitter_limitation_not_all_tweets_may_be_included,
                  style: TextStyle(
                    color: Theme.of(context).disabledColor,
                  ),
                )),
            ScopedBuilder<GroupModel, SubscriptionGroupGet>(
              store: model,
              onState: (_, state) {
                return Column(
                  children: [
                    SwitchListTile(
                        title: Text(
                          L10n.of(context).include_replies,
                        ),
                        value: model.state.includeReplies,
                        onChanged: (value) async {
                          await model.toggleSubscriptionGroupIncludeReplies(value);
                        }),
                    SwitchListTile(
                        title: Text(
                          L10n.of(context).include_retweets,
                        ),
                        value: model.state.includeRetweets,
                        onChanged: (value) async {
                          await model.toggleSubscriptionGroupIncludeRetweets(value);
                        }),
                  ],
                );
              },
            ),
          ],
        );
      });
}
