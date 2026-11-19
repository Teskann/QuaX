import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:quax/client/headers.dart';
import 'dart:async';

class XRegularAccount extends ChangeNotifier {
  static final log = Logger('XRegularAccount');

  XRegularAccount() : super();

  Future<http.Response> fetch(Uri uri,
      {Map<String, String>? headers,
      required Logger log,
      required Map<dynamic, dynamic> authHeader}) async {
    log.info('Fetching $uri');

    final baseHeaders = await TwitterHeaders.getHeaders(uri, authHeader);

    var response = await http.get(uri, headers: {
      ...?headers,
      ...baseHeaders
    });

    return response;
  }
}
