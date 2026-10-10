import 'dart:convert';
import 'dart:io';

import 'package:quax/database/entities.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';

const xWebOrigin = 'https://x.com';
const _cookieDomain = '.x.com';
const _httpOnlyCookie = 'auth_token';

typedef WebCookieSetter = Future<void> Function(List<Cookie> cookies, {String? origin});

Future<void> setWebCookies(List<Cookie> cookies, {String? origin}) =>
    WebviewCookieManager().setCookies(cookies, origin: origin);

/// The cookies of a `Cookie` header ("a=b;c=d") as X's web page expects them, so a web view is signed in as the account
/// the header belongs to. Malformed parts are ignored.
List<Cookie> xSessionCookies(String cookieHeader) =>
    cookieHeader.split(';').map(_parseCookie).nonNulls.toList();

Cookie? _parseCookie(String part) {
  final separator = part.indexOf('=');
  if (separator < 0) return null;
  final name = part.substring(0, separator).trim();
  if (name.isEmpty) return null;

  try {
    return Cookie(name, part.substring(separator + 1).trim())
      ..domain = _cookieDomain
      ..path = '/'
      ..secure = true
      ..httpOnly = name == _httpOnlyCookie;
  } on FormatException {
    return null;
  }
}

/// The web cookies of a stored account, whose auth header is a JSON object holding the `Cookie` header
List<Cookie> xAccountCookies(Account account) {
  final stored = account.authHeader;
  if (stored is! String) return [];

  try {
    final header = json.decode(stored);
    final cookie = header is Map ? header['Cookie'] : null;
    return xSessionCookies(cookie is String ? cookie : '');
  } on FormatException {
    return [];
  }
}
