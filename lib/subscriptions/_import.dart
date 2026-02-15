import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:quax/client/client.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/group/group_model.dart';
import 'package:quax/import_data_model.dart';
import 'package:quax/subscriptions/users_model.dart';
import 'package:quax/ui/errors.dart';
import 'package:provider/provider.dart';
import 'package:quax/generated/l10n.dart';

class SubscriptionImportScreen extends StatefulWidget {
  const SubscriptionImportScreen({super.key});

  @override
  State<SubscriptionImportScreen> createState() => _SubscriptionImportScreenState();
}

class _SubscriptionImportScreenState extends State<SubscriptionImportScreen> {
  String? _screenName;
  StreamController<int>? _streamController;

  Future importSubscriptions() async {
    setState(() {
      _streamController = StreamController();
    });

    try {
      var screenName = _screenName;
      if (screenName == null || screenName.isEmpty) {
        return;
      }

      _streamController?.add(0);

      int? cursor;
      int total = 0;

      // TODO: Test this still works
      var importModel = context.read<ImportDataModel>();
      var groupModel = context.read<GroupsModel>();

      var createdAt = DateTime.now();

      while (true) {
        var response = await Twitter.getProfileFollows(
          screenName,
          'following',
          cursor: cursor,
        );

        cursor = response.cursorBottom;
        total = total + response.users.length;

        await importModel.importData({
          tableSubscription: [
            ...response.users.map((e) => UserSubscription(
                id: e.idStr!,
                name: e.name!,
                profileImageUrlHttps: e.profileImageUrlHttps,
                screenName: e.screenName!,
                verified: e.verified ?? false,
                createdAt: createdAt))
          ]
        });

        _streamController?.add(total);

        if (cursor == 0 || cursor == -1) {
          break;
        }
      }

      await groupModel.reloadGroups();
      await context.read<SubscriptionsModel>().reloadSubscriptions();
      _streamController?.close();
    } catch (e, stackTrace) {
      _streamController?.addError(e, stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(L10n.of(context).import_subscriptions)),
      body: Padding(
          padding: EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  L10n.of(context).to_import_subscriptions_from_an_existing_twitter_account_enter_your_username_below,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  L10n.of(context)
                      .please_note_that_the_method_fritter_uses_to_import_subscriptions_is_heavily_rate_limited_by_twitter_so_this_may_fail_if_you_have_a_lot_of_followed_accounts,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: L10n.of(context).enter_your_twitter_username,
                    helperText: L10n.of(context).your_profile_must_be_public_otherwise_the_import_will_not_work,
                    prefixText: '@',
                    labelText: L10n.of(context).username,
                  ),
                  maxLength: 15,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[a-zA-Z0-9_]+'))],
                  onChanged: (value) {
                    setState(() {
                      _screenName = value;
                    });
                  },
                ),
              ),
              Center(
                child: StreamBuilder(
                  stream: _streamController?.stream,
                  builder: (context, snapshot) {
                    var error = snapshot.error;
                    if (error != null) {
                      return FullPageErrorWidget(
                        error: snapshot.error,
                        stackTrace: snapshot.stackTrace,
                        prefix: L10n.of(context).unable_to_import,
                      );
                    }

                    switch (snapshot.connectionState) {
                      case ConnectionState.none:
                      case ConnectionState.waiting:
                        return Container();
                      case ConnectionState.active:
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(),
                            ),
                            Text(
                              L10n.of(context).imported_snapshot_data_users_so_far(
                                snapshot.data.toString(),
                              ),
                            )
                          ],
                        );
                      default:
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Icon(Icons.check_circle, size: 36, color: Colors.green),
                            ),
                            Text(
                              L10n.of(context).finished_with_snapshotData_users(
                                snapshot.data.toString(),
                              ),
                            )
                          ],
                        );
                    }
                  },
                ),
              ),
            ],
          )),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.cloud_download),
        onPressed: () async => await importSubscriptions(),
      ),
    );
  }
}
