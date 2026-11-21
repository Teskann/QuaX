import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';
import 'package:quax/client/chrome.dart';
import 'package:quax/client/client_unauthenticated.dart';
import 'package:quax/client/headers.dart';
import 'package:quax/client/x_client_transaction_id/client_transaction.dart';
import 'package:quax/utils/urls.dart';

const _guestTokenPath = '/1.1/guest/activate.json';
const _unauthenticatedRequestPath = '/graphql/UserByScreenName';
const _transactionIdPagePath = '/home';
const _shortUrlPath = '/abc';
// Not a path: the headers of the logged-in API calls, read without sending a request
const _loggedInRequest = 'logged in request';

Future<Map<String, Map<String, String>>> _headersByRequest() async {
  final headers = <String, Map<String, String>>{};
  final fakeX = MockClient((request) async {
    headers[request.url.path] = request.headers;
    return switch (request.url.path) {
      _guestTokenPath => http.Response('{"guest_token": "1"}', 200),
      _transactionIdPagePath => http.Response('', 503),
      _ => http.Response('{}', 200),
    };
  });
  await http.runWithClient(() async {
    await fetchUnauthenticated(Uri.https('api.x.com', _unauthenticatedRequestPath), log: Logger('test'));
    // Fails on the 503 of the fake X. Only the request it sent matters.
    await ClientTransaction.initialize().then((_) {}, onError: (_) {});
    await parseUri(Uri.https('t.co', _shortUrlPath));
  }, () => fakeX);
  return headers;
}

Map<String, String?> _chromeHeadersIn(Map<String, String> headers) => {
  for (final name in chromeHeaders.keys) name: headers[name],
};

void main() {
  group('Requests to X', () {
    test('Should send the headers of the same Chrome on every request to X', () async {
      final headers = {...await _headersByRequest(), _loggedInRequest: await TwitterHeaders.getHeaders(null, null)};

      expect(
        headers.keys,
        containsAll([
          _guestTokenPath,
          _unauthenticatedRequestPath,
          _transactionIdPagePath,
          _shortUrlPath,
          _loggedInRequest,
        ]),
        reason: 'Every kind of request to X should have been sent',
      );
      expect(
        headers.values.map(_chromeHeadersIn),
        everyElement(chromeHeaders),
        reason: 'X sees several browsers in one session when the requests disagree',
      );
    });
  });

  group('Chrome identity', () {
    test('Should claim the same Chrome version in the user agent and in sec-ch-ua', () {
      final major = chromeFullVersion.split('.').first;
      expect(
        chromeUserAgent,
        contains('Chrome/$major.0.0.0'),
        reason: 'The user agent should claim Chrome $major, like sec-ch-ua does',
      );
      expect(
        chromeHeaders['sec-ch-ua'],
        contains('"Google Chrome";v="$major"'),
        reason: 'sec-ch-ua should claim Chrome $major, like the user agent does',
      );
    });

    test('Should build sec-ch-ua like the real Chrome', () {
      expect(
        chromeSecChUa('120.0.6099.109'),
        '"Not_A Brand";v="8", "Chromium";v="120", "Google Chrome";v="120"',
        reason: 'Chrome 120 sends exactly this. Any other value tells X it is not Chrome',
      );
      expect(
        chromeSecChUa('124.0.6367.60'),
        '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        reason: 'Chrome 124 sends exactly this. Any other value tells X it is not Chrome',
      );
      expect(
        chromeSecChUa('138.0.7204.97'),
        '"Not)A;Brand";v="8", "Chromium";v="138", "Google Chrome";v="138"',
        reason: 'Chrome 138 sends exactly this. Any other value tells X it is not Chrome',
      );
    });

    test('Should give the full version to Chromium and Google Chrome, but not to the fake brand', () {
      expect(
        chromeBrands('120.0.6099.109').map((brand) => '"${brand.name}";v="${brand.fullVersion}"').join(', '),
        '"Not_A Brand";v="8.0.0.0", "Chromium";v="120.0.6099.109", "Google Chrome";v="120.0.6099.109"',
        reason: 'Chrome 120.0.6099.109 sends exactly this full version list, which the login page can read',
      );
    });
  });
}
