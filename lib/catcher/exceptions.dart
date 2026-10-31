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
  final DateTime? availableAt;

  RateLimitedException([this.availableAt]);

  @override
  String toString() => 'Rate limited until $availableAt';
}

/// A feed that could only partly load because some of its searches were rate
/// limited: [loaded] of its [total] subscriptions could be loaded.
class FeedRateLimitedException extends RateLimitedException {
  final int loaded;
  final int total;

  FeedRateLimitedException(super.availableAt, {required this.loaded, required this.total});

  @override
  String toString() => 'Feed rate limited until $availableAt, $loaded/$total subscriptions loaded';
}

/// Thrown when X answers 401: it no longer accepts the session of the account, e.g. after a logout on x.com.
class SessionRejectedException with SyntheticException implements Exception {
  final String? screenName;

  SessionRejectedException(this.screenName);

  @override
  String toString() => 'X rejected the session of $screenName';
}

/// Thrown when X answers 404, which happens now and then in normal use. Surfaced
/// with a dedicated error widget offering to retry, rather than reported to the
/// crash catcher.
class NotFoundException with SyntheticException implements Exception {
  @override
  String toString() => 'Not found';
}

class ManuallyReportedException {
  final Object? exception;

  ManuallyReportedException(this.exception);
}

mixin SyntheticException {}

/// Errors X listed in the body of a GraphQL response, with or without the data that was asked for.
class XApiError implements Exception {
  final String message;
  final String? kind;
  final List<String> path;

  XApiError(this.message, {this.kind, this.path = const []});

  /// The errors of [body], or null when X listed none.
  static XApiError? fromBody(Map<String, dynamic> body) {
    final errors = List<Map<String, dynamic>>.from(body['errors'] as List? ?? const []);
    if (errors.isEmpty) {
      return null;
    }
    return XApiError(
      errors.map((e) => e['message'] as String? ?? '').join('\n'),
      kind: errors.first['kind'] as String?,
      path: List<String>.from((errors.first['path'] as List? ?? const []).whereType<String>()),
    );
  }

  /// X rejected the user search request
  bool get isRejectedSearch => kind == 'Validation' && path.contains('search_by_raw_query');

  @override
  String toString() => 'X returned an error: $message';
}

/// A search typed by the user that X refused to run. Not a bug of QuaX, so it is not offered for reporting.
class RejectedSearchException with SyntheticException implements Exception {
  final XApiError cause;

  RejectedSearchException(this.cause);

  @override
  String toString() => 'Search rejected by X: ${cause.message}';
}
