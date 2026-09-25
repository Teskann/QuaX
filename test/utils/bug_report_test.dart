import 'package:flutter_test/flutter_test.dart';
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
      startsWith('### Unable to load the profile\n\nVersion: 4.13.4\nProfile: @jack\n\n```'),
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
}
