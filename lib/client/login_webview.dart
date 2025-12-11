import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TwitterLoginWebview extends StatefulWidget {
  const TwitterLoginWebview({super.key});

  @override
  State<TwitterLoginWebview> createState() => _TwitterLoginWebviewState();
}

class _TwitterLoginWebviewState extends State<TwitterLoginWebview> {
  @override
  Widget build(BuildContext context) {
    WebViewPlatform.instance;
    final webviewCookieManager = WebviewCookieManager();
    final webviewController = WebViewController();
    webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
    webviewController.loadRequest(Uri.https("x.com", "i/flow/login"));
    webviewController.setUserAgent(userAgentHeader.toString());
    webviewController.setNavigationDelegate(NavigationDelegate(
      onUrlChange: (change) async {
        if (change.url == "https://x.com/home") {
          final cookies = await webviewCookieManager.getCookies("https://x.com/i/flow/login");
          String screenName = (await webviewController.runJavaScriptReturningResult(
                  "document.documentElement.outerHTML.match(/\"screen_name\":\"([^\"]+)\"/)?.[1] ?? '';"))
              .toString();
          screenName = screenName.replaceAll('"', '');
          if (screenName == "") return;

          try {
            final expCt0 = RegExp(r'(ct0=(.+?));');
            final RegExpMatch? matchCt0 = expCt0.firstMatch(cookies.toString());
            final csrfToken = matchCt0?.group(2);
            if (csrfToken != null) {
              final Map<String, String> authHeader = {
                "Cookie": cookies
                    .where((cookie) =>
                        cookie.name == "guest_id" ||
                        cookie.name == "gt" ||
                        cookie.name == "att" ||
                        cookie.name == "auth_token" ||
                        cookie.name == "ct0")
                    .map((cookie) => '${cookie.name}=${cookie.value}')
                    .join(";"),
                "authorization": bearerToken,
                "x-csrf-token": csrfToken,
              };

              final database = await Repository.writable();
              database.insert(tableAccounts,
                  Account(id: csrfToken, screenName: screenName, authHeader: json.encode(authHeader)).toMap());
              database.close();
            }
            if (context.mounted) {
              Navigator.pop(context);
            }
          } catch (e) {
            throw Exception(e);
          }
        }
      },
    ));
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 50,
      ),
      body: WebViewWidget(
        controller: webviewController,
      ),
    );
  }
}
