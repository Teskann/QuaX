import 'dart:async';
import 'dart:io';

import 'package:async_button_builder/async_button_builder.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quax/catcher/exceptions.dart';

import 'package:quax/client/client.dart';
import 'package:quax/client/login_webview.dart';
import 'package:quax/constants.dart';
import 'package:quax/generated/l10n.dart';
import 'package:quax/tweet/tweet.dart';
import 'package:quax/utils/bug_report.dart';
import 'package:quax/utils/urls.dart';

void showSnackBar(BuildContext context, {required String icon, required String message, bool clearBefore = true}) {
  if (clearBefore) {
    ScaffoldMessenger.of(context).clearSnackBars();
  }

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(message, style: const TextStyle(height: 1.5))),
        Text(icon),
      ],
    ),
  ));
}

/// Picks the message explaining what failed, so that it can be read in any language
typedef ErrorPrefix = String Function(L10n l10n);

abstract class FritterErrorWidget extends StatelessWidget {
  const FritterErrorWidget({super.key});
}

class UnknownTwitterErrorCode with SyntheticException implements Exception {
  final int code;
  final String message;
  final String uri;

  UnknownTwitterErrorCode(this.code, this.message, this.uri);

  @override
  String toString() {
    return 'Unknown Twitter error code: {code: $code, message: $message, uri: $uri}';
  }
}

/// Message explaining a known X error code
String twitterErrorMessage(TwitterError error) => switch (error.code) {
      22 => L10n.current.private_profile,
      34 => L10n.current.page_not_found,
      50 => L10n.current.user_not_found,
      63 => L10n.current.account_suspended,
      200 => L10n.current.forbidden,
      239 => L10n.current.bad_guest_token,
      _ => L10n.current.catastrophic_failure,
    };

class EmojiErrorWidget extends FritterErrorWidget {
  final String emoji;
  final String message;
  final String errorMessage;
  final Function? onRetry;
  final String? retryText;
  final bool showBackButton;

  const EmojiErrorWidget(
      {super.key,
      required this.emoji,
      required this.message,
      required this.errorMessage,
      this.onRetry,
      this.retryText,
      this.showBackButton = true});

  @override
  Widget build(BuildContext context) {
    var onRetry = this.onRetry;

    return Container(
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Text(emoji, style: const TextStyle(fontSize: 36)),
          ),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18)),
          Container(
            margin: const EdgeInsets.only(top: 12),
            child:
                Text(errorMessage, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (showBackButton)
              Container(
                margin: const EdgeInsets.only(top: 12),
                child: ElevatedButton(
                  child: Text(L10n.of(context).back),
                  onPressed: () {
                    // Check if we can actually pop the last route, as we might have opened here directly from another app
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                      return;
                    }

                    // If we're running on Android, close the app gracefully. Otherwise, return to the home screen
                    if (Platform.isAndroid) {
                      SystemNavigator.pop();
                    } else {
                      Navigator.pushReplacementNamed(context, routeHome);
                    }
                  },
                ),
              ),
            if (onRetry != null) const SizedBox(width: 16),
            if (onRetry != null)
              Container(
                margin: const EdgeInsets.only(top: 12),
                child: AsyncButtonBuilder(
                  showError: false,
                  showSuccess: false,
                  builder: (context, child, callback, buttonState) {
                    return ElevatedButton(
                      onPressed: callback,
                      child: child,
                    );
                  },
                  child: Text(retryText ?? L10n.current.retry),
                  onPressed: () => onRetry(),
                ),
              )
          ])
        ],
      ),
    );
  }
}

/// Opens the X login flow to add another account.
void openAddAccount(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const TwitterLoginWebview()));

class InlineErrorWidget extends FritterErrorWidget {
  final Object? error;

  const InlineErrorWidget({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Icon(Icons.error_outline, color: Colors.red.harmonizeWith(Theme.of(context).colorScheme.primary)),
          ),
          Text('$error', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).hintColor)),
        ],
      ),
    );
  }
}

class AlertErrorWidget extends FritterErrorWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final ErrorPrefix prefix;

  const AlertErrorWidget({super.key, required this.error, required this.stackTrace, required this.prefix});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: FullPageErrorWidget(error: error, prefix: prefix, stackTrace: stackTrace),
    );
  }
}

class ScaffoldErrorWidget extends FritterErrorWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final ErrorPrefix prefix;
  final Function? onRetry;
  final String? retryText;

  const ScaffoldErrorWidget(
      {super.key, required this.error, required this.stackTrace, required this.prefix, this.onRetry, this.retryText});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: FullPageErrorWidget(
          error: error, prefix: prefix, stackTrace: stackTrace, onRetry: onRetry, retryText: retryText),
    );
  }
}

class FullPageErrorWidget extends FritterErrorWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final ErrorPrefix prefix;
  final Function? onRetry;
  final String? retryText;

  /// Profile the error is about, mentioned in bug reports
  final String? screenName;

  const FullPageErrorWidget(
      {super.key,
      required this.error,
      required this.stackTrace,
      required this.prefix,
      this.onRetry,
      this.retryText,
      this.screenName});

  @override
  Widget build(BuildContext context) {
    final card = SingleChildScrollView(
      child: ErrorCard(
          error: error,
          stackTrace: stackTrace,
          prefix: prefix,
          onRetry: onRetry,
          retryText: retryText,
          screenName: screenName),
    );
    // Outside a scroll view, the error stands for a whole screen and must avoid the system bars itself. Inside one,
    // it sits below content that already does, such as a collapsing app bar, which leaves the padding in place
    return Scrollable.maybeOf(context) == null ? SafeArea(child: card) : card;
  }
}

/// Opens a GitHub issue prefilled with the error, the [screenName] of the profile it is about and the app version
Future<void> reportBug(BuildContext context,
    {required ErrorPrefix prefix, required Object? error, required StackTrace? stackTrace, String? screenName}) async {
  // In English whatever the language of the app, so that every report can be read
  final l10n = L10n.of(context);
  final englishPrefix = Intl.withLocale('en', () => prefix(l10n));
  final version = (await PackageInfo.fromPlatform()).version;
  if (!context.mounted) return;
  final uri = bugReportUri(englishPrefix, error, stackTrace, version: version, screenName: screenName);
  await openUri(context, uri.toString());
}

enum _PrimaryAction { report, addAccount }

typedef _CardContent = ({IconData icon, String title, String details, _PrimaryAction? primary});

/// Card explaining an error, with the action most likely to fix it. Used alone inside lists, and by
/// [FullPageErrorWidget] when there is nothing else to show
class ErrorCard extends StatelessWidget {
  final Object? error;
  final StackTrace? stackTrace;
  final ErrorPrefix prefix;
  final Function? onRetry;
  final String? retryText;

  /// Profile the error is about, mentioned in bug reports
  final String? screenName;

  const ErrorCard(
      {super.key,
      required this.error,
      required this.stackTrace,
      required this.prefix,
      this.onRetry,
      this.retryText,
      this.screenName});

  _CardContent _content(L10n l10n) {
    final error = this.error;
    return switch (error) {
      SocketException(:final message) => (
          icon: Icons.wifi_off,
          title: l10n.could_not_contact_twitter,
          details: l10n.please_check_your_internet_connection_error_message(message),
          primary: null,
        ),
      NoAccountAvailableException() => (
          icon: Icons.key,
          title: l10n.no_account_available_title,
          details: l10n.no_account_available_message,
          primary: _PrimaryAction.addAccount,
        ),
      RateLimitedException() => (
          icon: Icons.hourglass_empty,
          title: l10n.rate_limited_title,
          details: l10n.rate_limited_message,
          primary: _PrimaryAction.addAccount,
        ),
      NoWorkingAccountException() => (
          icon: Icons.person_off,
          title: l10n.no_working_account_title,
          details: l10n.no_working_account_message,
          primary: _PrimaryAction.addAccount,
        ),
      TwitterError() => (
          icon: Icons.error_outline,
          title: twitterErrorMessage(error),
          details: error.message,
          primary: null,
        ),
      TimeoutException() => (
          icon: Icons.timer_off,
          title: l10n.timed_out,
          details: l10n.this_took_too_long_to_load_please_check_your_network_connection,
          primary: null,
        ),
      _ => (icon: Icons.error_outline, title: prefix(l10n), details: '$error', primary: _PrimaryAction.report),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final content = _content(l10n);
    final onRetry = this.onRetry;

    return Card(
      color: tweetCardColor(context),
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _texts(context, content),
            const SizedBox(height: 16),
            OverflowBar(alignment: MainAxisAlignment.end, spacing: 4, children: [
              if (onRetry != null)
                TextButton(
                  onPressed: () => onRetry(),
                  child: Text(retryText ?? l10n.retry),
                ),
              if (content.primary != null) _primaryButton(context, content.primary!),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _texts(BuildContext context, _CardContent content) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(content.icon, size: 32, color: Colors.red.harmonizeWith(colors.primary)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(content.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(content.details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ]),
      ),
    ]);
  }

  Widget _primaryButton(BuildContext context, _PrimaryAction action) {
    final l10n = L10n.of(context);
    return switch (action) {
      _PrimaryAction.report => FilledButton(
          onPressed: () =>
              reportBug(context, prefix: prefix, error: error, stackTrace: stackTrace, screenName: screenName),
          child: Text(l10n.report),
        ),
      _PrimaryAction.addAccount => FilledButton(
          onPressed: () => openAddAccount(context),
          child: Text(l10n.add_account),
        ),
    };
  }
}
