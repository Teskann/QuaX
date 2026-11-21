import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/chrome.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/client/accounts.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/subscriptions/_import.dart' show SubscriptionImportScreen;
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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
  static const _userAgentMetadataChannel = MethodChannel('webview_user_agent_metadata');
  static final _log = Logger('TwitterLoginWebview');

  final _webviewCookieManager = WebviewCookieManager();
  final _webviewController = WebViewController();

  // X can report reaching its home page twice in a row. Handling both would save the account twice and close this
  // page twice, the second time closing the screen under it too.
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();
    unawaited(_setUpWebview());
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

  /// A setting that fails is only logged, so that the login page still loads.
  Future<void> _setUpWebview() async {
    try {
      await _webviewController.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _webviewController.setUserAgent(chromeUserAgent);
      await _setUserAgentMetadata();
      await _webviewController.setNavigationDelegate(_navigationDelegate());
    } catch (error) {
      _log.warning('Could not set up the login page', error);
    }
    // Last, so that the page loads with the user agent and metadata of Chrome
    await _webviewController.loadRequest(Uri.https("x.com", "i/flow/login"));
  }

  NavigationDelegate _navigationDelegate() => NavigationDelegate(
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
            await saveAccount(account);
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SubscriptionImportScreen(screenName: screenName)),
                      );
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
  );

  /// Logging in works without it, so a failure is only logged.
  Future<void> _setUserAgentMetadata() async {
    try {
      final webViewIdentifier = (_webviewController.platform as AndroidWebViewController).webViewIdentifier;
      final applied = await _userAgentMetadataChannel.invokeMethod<bool>(
        'set',
        _userAgentMetadataArguments(webViewIdentifier),
      );
      if (applied != true) _log.warning('This WebView cannot take the user agent metadata of Chrome');
    } catch (error) {
      _log.warning('Could not set the user agent metadata of the login page', error);
    }
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

// Keys read by WebViewUserAgentMetadata.kt
Map<String, Object> _userAgentMetadataArguments(int webViewIdentifier) => {
  'webViewIdentifier': webViewIdentifier,
  'brands': [
    for (final brand in chromeBrands(chromeFullVersion))
      {'name': brand.name, 'majorVersion': brand.majorVersion, 'fullVersion': brand.fullVersion},
  ],
  'fullVersion': chromeFullVersion,
};
