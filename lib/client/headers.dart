import 'package:quax/client/x_client_transaction_id/client_transaction.dart';
import 'package:quax/constants.dart';

class TwitterHeaders {
  static final Map<String, String> _baseHeaders = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.9',
    'authorization': bearerToken,
    'cache-control': 'no-cache',
    'content-type': 'application/json',
    'pragma': 'no-cache',
    'priority': 'u=1, i',
    'referer': 'https://x.com/',
    'user-agent': userAgentHeader['user-agent']!,
    'x-twitter-active-user': 'yes',
    'x-twitter-client-language': 'en',
  };

  static Future<ClientTransaction>? _initFuture;

  static Future<Map<String, String>?> getXClientTransactionIdHeader(Uri? uri) async {
    if (uri == null) {
      return null;
    }

    _initFuture ??= ClientTransaction.initialize();
    final ct = await _initFuture!;
    return {'x-client-transaction-id': ct.generateTransactionId('GET', uri.path)};
  }

  static Future<Map<String, String>> getHeaders(Uri? uri, Map<dynamic, dynamic>? authHeader) async {
    final xClientTransactionIdHeader = await getXClientTransactionIdHeader(uri);
    return {
      ..._baseHeaders,
      if (authHeader != null) ...Map<String, String>.from(authHeader),
      ...?xClientTransactionIdHeader
    };
  }
}
