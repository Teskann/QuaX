import 'package:http/http.dart';

class HttpException {
  final Response response;

  HttpException(this.response);

  int get statusCode => response.statusCode;
  String? get reasonPhrase => response.reasonPhrase;
  String get body => response.body;
  String? get uri => response.request?.url.toString();

  @override
  String toString() {
    return 'HttpException{statusCode: $statusCode, reasonPhrase: $reasonPhrase, uri: $uri, body: $body';
  }
}

/// Thrown when no account is usable (none added, or all currently flagged).
/// Surfaced to the user with a dedicated, actionable error widget rather than
/// reported to the crash catcher.
class NoAccountAvailableException with SyntheticException implements Exception {
  @override
  String toString() => 'No account available';
}

/// Thrown when every usable account is rate-limited (429) on the requested
/// endpoint. Surfaced to the user with a dedicated, actionable error widget
/// rather than reported to the crash catcher.
class RateLimitedException with SyntheticException implements Exception {
  @override
  String toString() => 'Rate limited';
}

/// Thrown when every account that was actually tried returned a 404, which on X
/// usually means the accounts are no longer correctly authenticated. Surfaced
/// with a dedicated, actionable error widget rather than reported to the crash
/// catcher.
class NoWorkingAccountException with SyntheticException implements Exception {
  @override
  String toString() => 'No working account';
}

class ManuallyReportedException {
  final Object? exception;

  ManuallyReportedException(this.exception);
}

mixin SyntheticException {}
