import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'router_snapshot.dart';

class RouterApiClient {
  RouterApiClient({
    this.host = '192.168.8.1',
    Duration? timeout,
    HttpClient? httpClient,
  })  : timeout = timeout ?? const Duration(seconds: 6),
        _httpClient = httpClient ?? HttpClient();

  static const preLoginInfoCommand = '7c6906a3-f7de-4795-a17e-ef032ffacda4';

  final String host;
  final Duration timeout;
  final HttpClient _httpClient;

  Future<RouterSnapshot> fetchSnapshot() async {
    final requestBody = jsonEncode(<String, String>{
      'cmd': preLoginInfoCommand,
      'method': 'GET',
      'sessionId': '',
    });

    final uri = Uri(
      scheme: 'http',
      host: host,
      path: '/cgi-bin/http.cgi',
    );

    final request = await _httpClient.postUrl(uri).timeout(timeout);
    request.headers.contentType = ContentType.json;
    request.write(requestBody);

    final response = await request.close().timeout(timeout);
    final body = await response.transform(utf8.decoder).join().timeout(timeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RouterApiException(
        'Router returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      return RouterSnapshot.fromJson(decoded);
    } on FormatException catch (error) {
      throw RouterApiException('Router returned invalid JSON: $error');
    }
  }

  void close() {
    _httpClient.close(force: true);
  }
}

class RouterApiException implements Exception {
  const RouterApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
