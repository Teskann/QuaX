import 'package:quax/constants.dart';

// Undocumented GitHub limit, measured around 7000 for logged out users, whose URL gets re-encoded into a login redirect
const bugReportMaxUrlLength = 6500;
const _maxTitleLength = 100;
const _maxErrorLength = 1000;

String _truncate(String text, int maxLength) => text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';

Uri _issueUri(String title, String header, String error, List<String> stackLines) =>
    Uri.parse('$issuesUrl/new')
        .replace(queryParameters: {'title': title, 'body': '$header```\n$error\n${stackLines.join('\n')}\n```'});

Uri bugReportUri(String context, Object? error, StackTrace? stackTrace, {required String version, String? screenName}) {
  final facts = ['Version: $version', if (screenName != null) 'Profile: @$screenName'];
  final header = '### $context\n\n${facts.join('\n')}\n\n';
  final errorText = _truncate('$error', _maxErrorLength);
  final title = _truncate(errorText.split('\n').first, _maxTitleLength);
  final lines = stackTrace == null ? <String>[] : '$stackTrace'.trimRight().split('\n');
  return List.generate(lines.length + 1, (dropped) => lines.sublist(0, lines.length - dropped))
      .map((kept) => _issueUri(title, header, errorText, kept))
      .firstWhere(
        (uri) => uri.toString().length <= bugReportMaxUrlLength,
        orElse: () => _issueUri(title, header, errorText, const []),
      );
}
