import 'package:flutter/material.dart';
import 'package:quax/client/client_regular_account.dart';
import 'package:quax/client/login_webview.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/client/accounts.dart';

class SettingsAccountFragment extends StatefulWidget {
  const SettingsAccountFragment({super.key});

  @override
  State<SettingsAccountFragment> createState() => _SettingsAccountFragment();
}

class _SettingsAccountFragment extends State<SettingsAccountFragment> {
  @override
  Widget build(BuildContext context) {
    var model = XRegularAccount();
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.current.account),
        actions: [
          IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TwitterLoginWebview())),
              icon: const Icon(Icons.add))
        ],
      ),
      body: FutureBuilder(
          future: getAccounts(),
          builder: (BuildContext listContext, AsyncSnapshot snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            } else {
              List<Account> data = snapshot.data;
              return ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (BuildContext itemContext, int index) {
                    return Dismissible(
                        key: widget.key!,
                        onDismissed: (DismissDirection direction) async {
                          await model.deleteAccount(data[index].id.toString());
                          setState(() {});
                        },
                        child: Card(
                            child: ListTile(
                          title: Text(data[index].screenName ?? L10n.of(context).unknown_username),
                          leading: const Icon(Icons.account_circle),
                        )));
                  });
            }
          }),
    );
  }
}
