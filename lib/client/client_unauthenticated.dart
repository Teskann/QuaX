import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:quax/constants.dart';

String? _guestToken;
const int _expiresAt = -1;
const int _tokenLimit = -1;
const int _tokenRemaining = -1;

int tokenLimit = -1;
int tokenRemaining = -1;
int expiresAt = -1;

Future<String> getToken(Logger log) async {
  if (_guestToken != null) {
    // If we don't have an expiry or limit, it's probably because we haven't made a request yet, so assume they're OK
    if (_expiresAt == -1 && _tokenLimit == -1 && _tokenRemaining == -1) {
      // TODO: Null safety with concurrent threads
      return _guestToken!;
    }

    // Check if the token we have hasn't expired yet
    if (DateTime.now().millisecondsSinceEpoch < _expiresAt) {
      // Check if the token we have still has usages remaining
      if (_tokenRemaining < _tokenLimit) {
        // TODO: Null safety with concurrent threads
        return _guestToken!;
      }
    }
  }

  log.info('Refreshing the X token');

  var response = await http.post(Uri.parse('https://api.x.com/1.1/guest/activate.json'), headers: {
    'Authorization':
        'Bearer AAAAAAAAAAAAAAAAAAAAAGHtAgAAAAAA%2Bx7ILXNILCqkSGIzy6faIHZ9s3Q%3DQy97w6SIrzE7lQwPJEYQBsArEE2fC25caFwRBvAGi456G09vGR',
  });

  if (response.statusCode == 200) {
    var result = jsonDecode(response.body);
    if (result.containsKey('guest_token')) {
      _guestToken = result['guest_token'];

      return _guestToken!;
    }
  }

  _guestToken = null;

  throw Exception(
      'Unable to refresh the token. The response (${response.statusCode}) from Twitter was: ${response.body}');
}

Future<http.Response> fetchUnauthenticated(Uri uri, {Map<String, String>? headers, required Logger log}) async {
  log.info('Fetching (unauthenticated) $uri');

  var response = await http.get(uri, headers: {
    ...?headers,
    'Authorization':
        'Bearer AAAAAAAAAAAAAAAAAAAAAGHtAgAAAAAA%2Bx7ILXNILCqkSGIzy6faIHZ9s3Q%3DQy97w6SIrzE7lQwPJEYQBsArEE2fC25caFwRBvAGi456G09vGR',
    'x-guest-token': await getToken(log),
    'x-twitter-active-user': 'yes',
    'user-agent': userAgentHeader.toString()
  });

  var headerRateLimitReset = response.headers['x-rate-limit-reset'];
  var headerRateLimitRemaining = response.headers['x-rate-limit-remaining'];
  var headerRateLimitLimit = response.headers['x-rate-limit-limit'];

  if (headerRateLimitReset == null || headerRateLimitRemaining == null || headerRateLimitLimit == null) {
    // If the rate limit headers are missing, the endpoint probably doesn't send them back
    return response;
  }

  // Update our token's rate limit counters
  expiresAt = int.parse(headerRateLimitReset) * 1000;
  tokenRemaining = int.parse(headerRateLimitRemaining);
  tokenLimit = int.parse(headerRateLimitLimit);

  return response;
}
