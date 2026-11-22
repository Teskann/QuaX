import 'package:flutter_test/flutter_test.dart';
import 'package:quax/catcher/exceptions.dart';
import 'package:quax/client/x_client_transaction_id/client_transaction_id_exception.dart';
import 'package:quax/utils/bug_report.dart';

StackTrace fakeStackTrace(int frames) => StackTrace.fromString(
  List.generate(frames, (i) => '#$i      SomeClass.someMethod (package:quax/some/file.dart:$i:1)').join('\n'),
);

void main() {
  test('Should open the new issue form of the QuaX repository', () {
    final uri = bugReportUri('Unable to load the tweets', 'boom', null, version: '4.13.4');
    expect(
      uri.toString(),
      startsWith('https://github.com/teskann/quax/issues/new?'),
      reason: 'The link should land on the issue form, not on the issue list',
    );
  });

  test(
    'Should head the description with what failed and the version, then the error and stack trace in a code block',
    () {
      final body = bugReportUri(
        'Unable to load the tweets',
        'boom',
        fakeStackTrace(2),
        version: '4.13.4',
      ).queryParameters['body'];
      expect(
        body,
        '### Unable to load the tweets\n\n'
        'Version: 4.13.4\n\n'
        '```\nboom\n'
        '#0      SomeClass.someMethod (package:quax/some/file.dart:0:1)\n'
        '#1      SomeClass.someMethod (package:quax/some/file.dart:1:1)\n```',
        reason: 'A code block keeps the stack trace readable on GitHub',
      );
    },
  );

  test('Should mention the profile the error is about when there is one', () {
    final body = bugReportUri(
      'Unable to load the profile',
      'boom',
      null,
      version: '4.13.4',
      screenName: 'jack',
    ).queryParameters['body'];
    expect(
      body,
      startsWith('### Unable to load the profile\n\nVersion: 4.13.4\nProfile: https://x.com/jack\n\n```'),
      reason: 'Profile errors often depend on the profile, so we need it to reproduce them',
    );
  });

  test('Should mention no profile when the error is not about one', () {
    final body = bugReportUri('Unable to load the tweets', 'boom', null, version: '4.13.4').queryParameters['body'];
    expect(body, isNot(contains('Profile:')), reason: 'An empty profile line would only be noise');
  });

  test('Should title the issue with the first line of the error', () {
    final title = bugReportUri(
      'Unable to load the tweets',
      'boom\nmore details',
      null,
      version: '4.13.4',
    ).queryParameters['title'];
    expect(title, 'boom', reason: 'A multiline title would be unreadable in the issue list');
  });

  test('Should drop the deepest frames when the stack trace does not fit in a URL', () {
    final uri = bugReportUri('Unable to load the tweets', 'boom', fakeStackTrace(1000), version: '4.13.4');
    final body = uri.queryParameters['body']!;
    expect(
      uri.toString().length,
      lessThanOrEqualTo(bugReportMaxUrlLength),
      reason: 'GitHub refuses URLs that are too long, which would make reporting impossible',
    );
    expect(body, contains('#0 '), reason: 'The top frames locate the bug and should be kept');
    expect(body, isNot(contains('#999 ')), reason: 'The deepest frames should be the ones dropped');
    expect(body, endsWith('\n```'), reason: 'The code block should still be closed after truncation');
  });

  test('Should carry the marker that triggers the fix workflow when the transaction id could not be built', () {
    final body = bugReportUri(
      'Unable to load the tweets',
      const ClientTransactionIdException("Couldn't find the sign module"),
      null,
      version: '4.13.4',
    ).queryParameters['body'];
    expect(
      body,
      contains(clientTransactionIdReportMarker),
      reason: 'The workflow only starts the fix routine for reports carrying the marker',
    );
  });

  test('Should carry no marker for any other error', () {
    final body = bugReportUri('Unable to load the tweets', Exception('boom'), null, version: '4.13.4')
        .queryParameters['body'];
    expect(
      body,
      isNot(contains(clientTransactionIdReportMarker)),
      reason: 'A marker on unrelated reports would start the fix routine for nothing',
    );
  });

  test('Should carry every detail X gave about its errors when X returned an error', () {
    final error = XApiError('Dependency: Unspecified', errors: [
      {
        'message': 'Dependency: Unspecified',
        'code': 64,
        'extensions': {'name': 'DependencyError', 'source': 'Server'},
      },
    ]);
    final body = bugReportUri('Unable to load the tweets', error, null, version: '4.13.4').queryParameters['body']!;
    expect(body, contains('Errors listed by X:\n```\n[{"message":"Dependency: Unspecified","code":64,'),
        reason: 'The code of X tells a server failure from a wrong request, the message alone does not');
    expect(body, contains('"extensions":{"name":"DependencyError","source":"Server"}'),
        reason: 'The extensions name the part of X that failed');
  });

  test('Should keep a truncated copy of the errors of X when they are too long for a URL', () {
    final longTrace = List.filled(5000, 'x').join();
    final error = XApiError('Dependency: Unspecified', errors: [
      {'message': 'Dependency: Unspecified', 'trace': longTrace},
    ]);
    final uri = bugReportUri('Unable to load the tweets', error, fakeStackTrace(1000), version: '4.13.4');
    expect(uri.toString().length, lessThanOrEqualTo(bugReportMaxUrlLength),
        reason: 'GitHub refuses URLs that are too long, which would make reporting impossible');
    expect(uri.queryParameters['body'], contains('Errors listed by X:\n```\n[{"message":"Dependency: Unspecified"'),
        reason: 'The start of the errors of X still tells what failed');
  });

  test('Should drop the errors of X when even a truncated copy does not fit in a URL', () {
    // Quotes are escaped by JSON then by the URL, so they take much more room once encoded
    final quotes = List.filled(2000, '"').join();
    final error = XApiError(quotes, errors: [
      {'message': quotes},
    ]);
    final uri = bugReportUri('Unable to load the tweets', error, null, version: '4.13.4');
    expect(uri.toString().length, lessThanOrEqualTo(bugReportMaxUrlLength),
        reason: 'Reporting should stay possible, even without the errors of X');
    expect(uri.queryParameters['body'], isNot(contains('Errors listed by X:')),
        reason: 'The errors of X are the last thing dropped to fit in a URL');
  });
}
