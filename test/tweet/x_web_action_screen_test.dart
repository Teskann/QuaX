import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/constants.dart';
import 'package:quax/database/entities.dart';
import 'package:quax/tweet/x_web_action_screen.dart';
import 'package:quax/tweet/x_web_page.dart';

import '../ui/pump_app.dart';

const _replyUri = 'https://x.com/intent/post?in_reply_to=20';

/// Records what the screen does to the page, in order, and lets the test play what the page reports
class _FakePage implements XWebPage {
  final List<String> calls;
  late XWebPageEvents events;
  String? userAgent;

  _FakePage(this.calls);

  @override
  Future<void> setUp({required String userAgent, required XWebPageEvents events}) async {
    calls.add('setUp');
    this.userAgent = userAgent;
    this.events = events;
  }

  @override
  Future<void> load(Uri uri) async => calls.add('load $uri');

  @override
  Widget build() => const SizedBox(key: Key('fake-page'));

  void finishLoading(String url) => events.onPageFinished(Uri.parse(url));

  void navigateTo(String url) => events.onUrlChange(Uri.parse(url));
}

class _PopCounter extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => pops++;
}

final _account = Account(
  id: 'csrf',
  authHeader: json.encode({'Cookie': 'guest_id=v1;auth_token=tok;ct0=csrf'}),
  screenName: 'ada',
);

class _Harness {
  final WidgetTester tester;
  final calls = <String>[];
  final pops = _PopCounter();
  late final _FakePage page = _FakePage(calls);
  List<Cookie> cookies = [];
  String? origin;

  _Harness(this.tester);

  Future<void> open({Account? account, String uri = _replyUri, String title = 'Reply'}) async {
    await pumpInApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => XWebActionScreen(
                uri: uri,
                title: title,
                loadAccount: () async => account,
                setCookies: (cookies, {origin}) async {
                  calls.add('cookies');
                  this.cookies = cookies;
                  this.origin = origin;
                },
                createPage: () => page,
              ),
            ),
          ),
          child: const Text('open'),
        ),
      ),
      settle: false,
      navigatorObservers: [pops],
    );
    await tester.tap(find.text('open'));
    await _settleRoute();
    pops.pops = 0;
  }

  Future<void> _settleRoute() async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> pageReports(void Function() report) async {
    report();
    await _settleRoute();
  }
}

void main() {
  group('Opening the page', () {
    testWidgets('Should sign in with the cookies of the first account on x.com before loading the page', (tester) async {
      final harness = _Harness(tester);

      await harness.open(account: _account);

      expect(harness.calls, ['setUp', 'cookies', 'load $_replyUri'],
          reason: 'The cookies must be set before the page is requested');
      expect(harness.cookies.map((e) => e.name), ['guest_id', 'auth_token', 'ct0'],
          reason: 'The cookies of the account should be given to the web view');
      expect(harness.origin, 'https://x.com', reason: 'The cookies belong to x.com');
    });

    testWidgets('Should only load the page, for X to ask for the login, when there is no account', (tester) async {
      final harness = _Harness(tester);

      await harness.open();

      expect(harness.calls, ['setUp', 'load $_replyUri'], reason: 'No cookie should be set without an account');
    });

    testWidgets('Should load the address it was given', (tester) async {
      final harness = _Harness(tester);

      await harness.open(uri: 'https://x.com/intent/retweet?tweet_id=20');

      expect(harness.calls.last, 'load https://x.com/intent/retweet?tweet_id=20',
          reason: 'The repost page is not the reply page');
    });

    testWidgets('Should present itself as the login page does', (tester) async {
      final harness = _Harness(tester);

      await harness.open();

      expect(harness.page.userAgent, userAgentHeader.toString(), reason: 'X should see the same browser as at login');
    });

    testWidgets('Should show the web page', (tester) async {
      await _Harness(tester).open();

      expect(find.byKey(const Key('fake-page')), findsOneWidget, reason: 'The page fills the screen');
    });
  });

  group('App bar', () {
    for (final title in ['Reply', 'Repost']) {
      testWidgets('Should be titled $title', (tester) async {
        await _Harness(tester).open(title: title);

        expect(find.descendant(of: find.byType(AppBar), matching: find.text(title)), findsOneWidget,
            reason: 'The title tells which action the page is for');
      });
    }

    testWidgets('Should have a close button on the left', (tester) async {
      await _Harness(tester).open();

      final close = find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.close));
      expect(close, findsOneWidget, reason: 'The page is closed with an X, as in the X app');
      expect(tester.getCenter(close).dx, lessThan(tester.getCenter(find.text('Reply')).dx),
          reason: 'The close button is on the left of the title');
    });

    testWidgets('Should show an indeterminate progress bar until the page reports progress', (tester) async {
      await _Harness(tester).open();

      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(bar.value, isNull, reason: 'Nothing is known about the progress yet');
    });

    testWidgets('Should show the progress of the page, and hide it once the page is loaded', (tester) async {
      final harness = _Harness(tester);
      await harness.open();

      await harness.pageReports(() => harness.page.events.onProgress(40));
      expect(tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator)).value, 0.4,
          reason: 'The bar follows the progress of the page');

      await harness.pageReports(() => harness.page.events.onProgress(100));
      expect(find.byType(LinearProgressIndicator), findsNothing, reason: 'Nothing is loading anymore');
    });
  });

  group('Closing', () {
    testWidgets('Should close with a Done message when X leaves the intent page after the action', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.pageReports(() => harness.page.finishLoading(_replyUri));

      await harness.pageReports(() => harness.page.navigateTo('https://x.com/home'));

      expect(find.byType(XWebActionScreen), findsNothing, reason: 'The action is over, so the page closes');
      expect(find.text('Done'), findsOneWidget, reason: 'The user is told the action went through');
      expect(harness.pops.pops, 1, reason: 'The page closes once');
    });

    testWidgets('Should close only once when X reports leaving the intent page several times', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.pageReports(() => harness.page.finishLoading(_replyUri));

      await harness.pageReports(() {
        harness.page.navigateTo('https://x.com/home');
        harness.page.navigateTo('https://x.com/home');
        harness.page.navigateTo('https://x.com/jack/status/20');
      });

      expect(harness.pops.pops, 1, reason: 'A second pop would close the screen under the page too');
      expect(find.byType(TextButton), findsOneWidget, reason: 'The screen under the page stays');
      expect(find.text('Done'), findsOneWidget, reason: 'One message is enough');
    });

    testWidgets('Should stay open while X only changes the query of the intent page', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.pageReports(() => harness.page.finishLoading(_replyUri));

      await harness.pageReports(() => harness.page.navigateTo('$_replyUri&text=hi'));

      expect(find.byType(XWebActionScreen), findsOneWidget, reason: 'The action is not over');
      expect(find.text('Done'), findsNothing, reason: 'Nothing was done yet');
    });

    testWidgets('Should stay open while X redirects before the first page finished loading', (tester) async {
      final harness = _Harness(tester);
      await harness.open();

      await harness.pageReports(() => harness.page.navigateTo('https://x.com/i/flow/login'));

      expect(find.byType(XWebActionScreen), findsOneWidget, reason: 'A redirect while loading is not the end');
    });

    testWidgets('Should stay open when X asks for the login, however the user moves in it', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await harness.pageReports(() => harness.page.finishLoading('https://x.com/i/flow/login'));

      await harness.pageReports(() => harness.page.navigateTo('https://x.com/home'));

      expect(find.byType(XWebActionScreen), findsOneWidget, reason: 'Logging in must not close the page');
      expect(find.text('Done'), findsNothing, reason: 'The action was not sent');
    });

    testWidgets('Should close without any message from the close button', (tester) async {
      final harness = _Harness(tester);
      await harness.open();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(XWebActionScreen), findsNothing, reason: 'The button closes the page');
      expect(find.byType(SnackBar), findsNothing, reason: 'Nothing was done, so there is nothing to confirm');
      expect(harness.pops.pops, 1, reason: 'The page closes once');
    });

    testWidgets('Should close without any message from the system back button', (tester) async {
      final harness = _Harness(tester);
      await harness.open();

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(XWebActionScreen), findsNothing, reason: 'Back leaves the page');
      expect(find.byType(SnackBar), findsNothing, reason: 'Nothing was done, so there is nothing to confirm');
    });

    testWidgets('Should ignore what the page reports once the user closed it', (tester) async {
      final harness = _Harness(tester);
      await harness.open();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump(const Duration(milliseconds: 500));

      harness.page.events.onProgress(50);
      harness.page.finishLoading(_replyUri);
      harness.page.navigateTo('https://x.com/home');
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull, reason: 'A closed screen has no one left to tell');
      expect(find.text('Done'), findsNothing, reason: 'The user closed the page; nothing was done');
      expect(harness.pops.pops, 1, reason: 'Only the close button popped');
    });
  });
}
