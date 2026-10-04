import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/_import.dart' show SubscriptionImportScreen;
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Logs in to X, then closes with the account. When [guided], another screen already explained the login and offers
/// the next steps, so no dialog is shown.
class TwitterLoginWebview extends StatefulWidget {
  final bool guided;

  const TwitterLoginWebview({super.key, this.guided = false});

  @override
  State<TwitterLoginWebview> createState() => _TwitterLoginWebviewState();
}

class _TwitterLoginWebviewState extends State<TwitterLoginWebview> {
  static const _channel = MethodChannel('browser_resolver');

  final _webviewCookieManager = WebviewCookieManager();
  final _webviewController = WebViewController();

  // X can report reaching its home page twice in a row. Handling both would save the account twice and close this
  // page twice, the second time closing the screen under it too.
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();
    _setUpWebview();
    if (widget.guided) {
      return;
    }
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
        // Lets "Sign in with Google" open its popup, which webview_flutter does not support
        onPageStarted: (_) => _channel.invokeMethod<void>('enableWebViewPopups'),
        onUrlChange: (change) async {
          if (change.url == "https://x.com/home" && !_loggingIn) {
            _loggingIn = true;
            final cookies = await _webviewCookieManager.getCookies("https://x.com/i/flow/login");
            final screenName = await _readScreenName();
            if (screenName == "") {
              _loggingIn = false;
              return;
            }

            Account? account;
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

                account = Account(id: csrfToken, screenName: screenName, authHeader: json.encode(authHeader));
                final database = await Repository.writable();
                await database.insert(tableAccounts, account.toMap());
                database.close();
              }
              if (mounted && widget.guided) {
                Navigator.pop(context, account);
              } else if (mounted) {
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

  /// X's home page fills in the screen name after the URL changed, and no other URL change follows, so wait for it.
  Future<String> _readScreenName() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      final result = await _webviewController.runJavaScriptReturningResult(
        "document.documentElement.outerHTML.match(/\"screen_name\":\"([^\"]+)\"/)?.[1] ?? '';",
      );
      final screenName = result.toString().replaceAll('"', '');
      if (screenName != "") {
        return screenName;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(toolbarHeight: 50),
      body: SafeArea(top: false, child: WebViewWidget(controller: _webviewController)),
    );
  }
}
