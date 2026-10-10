import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quax/client/x_web_session.dart';
import 'package:quax/database/entities.dart';

Map<String, String> _asMap(List<Cookie> cookies) => {for (final cookie in cookies) cookie.name: cookie.value};

Account _account(Object? authHeader) => Account(id: 'ct0', authHeader: authHeader, screenName: 'ada');

void main() {
  group('xSessionCookies', () {
    test('Should read every cookie of the header, in order', () {
      final cookies = xSessionCookies('guest_id=v1%3A1;gt=22;att=1-abc;auth_token=tok;ct0=csrf');

      expect(cookies.map((e) => e.name), ['guest_id', 'gt', 'att', 'auth_token', 'ct0'],
          reason: 'Every cookie of the header should be kept');
      expect(_asMap(cookies), {'guest_id': 'v1%3A1', 'gt': '22', 'att': '1-abc', 'auth_token': 'tok', 'ct0': 'csrf'},
          reason: 'Each cookie should hold its own value');
    });

    test('Should tolerate spaces around the parts, names and values', () {
      final cookies = xSessionCookies('  auth_token = tok ; ct0=csrf ;');

      expect(_asMap(cookies), {'auth_token': 'tok', 'ct0': 'csrf'}, reason: 'Spaces are not part of the cookies');
    });

    test('Should skip empty parts', () {
      final cookies = xSessionCookies(';;auth_token=tok;; ;ct0=csrf;');

      expect(cookies.map((e) => e.name), ['auth_token', 'ct0'], reason: 'Empty parts hold no cookie');
    });

    test('Should keep the equal signs inside a value', () {
      final cookies = xSessionCookies('att=a=b==;ct0=csrf');

      expect(_asMap(cookies)['att'], 'a=b==', reason: 'Only the first equal sign separates name and value');
      expect(_asMap(cookies)['ct0'], 'csrf', reason: 'The next cookie should not be affected');
    });

    test('Should ignore malformed parts and keep the valid ones', () {
      final cookies = xSessionCookies('novalue;=nameless;bad name=1;ct0=csrf');

      expect(cookies.map((e) => e.name), ['ct0'],
          reason: 'A part without equal sign, without name or with an invalid name is not a cookie');
    });

    test('Should not require an auth_token', () {
      final cookies = xSessionCookies('guest_id=v1;ct0=csrf');

      expect(cookies.map((e) => e.name), ['guest_id', 'ct0'], reason: 'Missing auth_token only means a guest session');
    });

    test('Should return nothing for an empty header', () {
      expect(xSessionCookies(''), isEmpty, reason: 'There is nothing to read');
    });

    test('Should scope every cookie to x.com over https, for the whole site', () {
      final cookies = xSessionCookies('guest_id=v1;auth_token=tok;ct0=csrf');

      expect(cookies.map((e) => e.domain), everyElement('.x.com'), reason: 'Cookies are for x.com and its subdomains');
      expect(cookies.map((e) => e.path), everyElement('/'), reason: 'Cookies are for the whole site');
      expect(cookies.map((e) => e.secure), everyElement(isTrue), reason: 'X only takes them over https');
    });

    test('Should make only auth_token inaccessible to scripts', () {
      final cookies = {for (final cookie in xSessionCookies('guest_id=v1;auth_token=tok;ct0=csrf')) cookie.name: cookie};

      expect(cookies['auth_token']!.httpOnly, isTrue, reason: 'X sets auth_token as HttpOnly');
      expect(cookies['ct0']!.httpOnly, isFalse, reason: 'X reads ct0 from script to send it back as a header');
      expect(cookies['guest_id']!.httpOnly, isFalse, reason: 'Only auth_token is HttpOnly');
    });
  });

  group('xAccountCookies', () {
    test('Should read the cookies from the Cookie header stored with the account', () {
      final header =
          json.encode({'Cookie': 'auth_token=tok;ct0=csrf', 'authorization': 'Bearer x', 'x-csrf-token': 'csrf'});

      expect(_asMap(xAccountCookies(_account(header))), {'auth_token': 'tok', 'ct0': 'csrf'},
          reason: 'The web view should get the cookies of the account');
    });

    test('Should return nothing when the stored header has no Cookie', () {
      expect(xAccountCookies(_account(json.encode({'authorization': 'Bearer x'}))), isEmpty,
          reason: 'Without a Cookie header there is nothing to sign in with');
      expect(xAccountCookies(_account(json.encode({'Cookie': 12}))), isEmpty,
          reason: 'A Cookie that is not text is not usable');
    });

    test('Should return nothing when the stored header is not an object', () {
      expect(xAccountCookies(_account(json.encode(['Cookie']))), isEmpty, reason: 'A list holds no Cookie header');
    });

    test('Should return nothing when the stored header is not JSON', () {
      expect(xAccountCookies(_account('auth_token=tok')), isEmpty, reason: 'Unreadable headers must not crash');
    });

    test('Should return nothing when the account has no stored header', () {
      expect(xAccountCookies(_account(null)), isEmpty, reason: 'A missing header must not crash');
    });
  });
}
