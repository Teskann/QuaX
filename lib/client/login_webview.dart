import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/_import.dart' show SubscriptionImportScreen;
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TwitterLoginWebview extends StatefulWidget {
  const TwitterLoginWebview({super.key});

  @override
  State<TwitterLoginWebview> createState() => _TwitterLoginWebviewState();
}

class _TwitterLoginWebviewState extends State<TwitterLoginWebview> {
  final _webviewCookieManager = WebviewCookieManager();
  final _webviewController = WebViewController();

  @override
  void initState() {
    super.initState();
    _setUpWebview();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(L10n.of(context).logging_in_quax),
          content: Text(L10n.of(context).logging_in_quax_information),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(L10n.of(context).ok),
            ),
          ],
        ),
      );
    });
  }

  void _setUpWebview() {
    _webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    _webviewController.loadRequest(Uri.https("x.com", "i/flow/login"));
    _webviewController.setUserAgent(userAgentHeader.toString());
    _webviewController.setNavigationDelegate(
      NavigationDelegate(
        onUrlChange: (change) async {
          if (change.url == "https://x.com/home") {
            final cookies = await _webviewCookieManager.getCookies("https://x.com/i/flow/login");
            String screenName = (await _webviewController.runJavaScriptReturningResult(
              "document.documentElement.outerHTML.match(/\"screen_name\":\"([^\"]+)\"/)?.[1] ?? '';",
            )).toString();
            screenName = screenName.replaceAll('"', '');
            if (screenName == "") return;

            try {
              final expCt0 = RegExp(r'(ct0=(.+?));');
              final RegExpMatch? matchCt0 = expCt0.firstMatch(cookies.toString());
              final csrfToken = matchCt0?.group(2);
              if (csrfToken != null) {
                final Map<String, String> authHeader = {
                  "Cookie": cookies
                      .where(
                        (cookie) =>
                            cookie.name == "guest_id" ||
                            cookie.name == "gt" ||
                            cookie.name == "att" ||
                            cookie.name == "auth_token" ||
                            cookie.name == "ct0",
                      )
                      .map((cookie) => '${cookie.name}=${cookie.value}')
                      .join(";"),
                  "authorization": bearerToken,
                  "x-csrf-token": csrfToken,
                };

                final database = await Repository.writable();
                database.insert(
                  tableAccounts,
                  Account(id: csrfToken, screenName: screenName, authHeader: json.encode(authHeader)).toMap(),
                );
                database.close();
              }
              if (mounted) {
                Navigator.pop(context);
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(L10n.of(context).import_subscriptions),
                    content: Text(L10n.of(context).import_subscriptions_text(screenName)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: Text(L10n.of(context).no)),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => SubscriptionImportScreen(screenName: screenName)));
                        },
                        child: Text(L10n.of(context).yes),
                      ),
                    ],
                  ),
                );
              }
            } catch (e) {
              throw Exception(e);
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 50),
      body: WebViewWidget(controller: _webviewController),
    );
  }
}
