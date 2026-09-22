import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'router_snapshot.dart';

class RouterApiClient {
  RouterApiClient({
    this.host = '192.168.8.1',
    this.port = 80,
    Duration? timeout,
  }) : timeout = timeout ?? const Duration(seconds: 6);

  static const preLoginInfoCommand = '7c6906a3-f7de-4795-a17e-ef032ffacda4';

  final String host;
  final int port;
  final Duration timeout;

  Future<RouterSnapshot> fetchSnapshot() async {
    final requestBody = jsonEncode(<String, String>{
      'cmd': preLoginInfoCommand,
      'method': 'GET',
      'sessionId': '',
    });

    final response = await _sendRequest(requestBody);
    final body = utf8.decode(response.body);

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

  void close() {}

  Future<_RawHttpResponse> _sendRequest(String body) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      socket.write(
        'POST /cgi-bin/http.cgi HTTP/1.1\r\n'
        'Host: $host\r\n'
        'Content-Type: application/json\r\n'
        'Content-Length: ${utf8.encode(body).length}\r\n'
        'Connection: close\r\n\r\n'
        '$body',
      );
      await socket.flush().timeout(timeout);
      final bytes = await socket.timeout(timeout).fold<List<int>>(
        <int>[],
        (received, chunk) => received..addAll(chunk),
      );
      return _RawHttpResponse.parse(bytes);
    } finally {
      socket.destroy();
    }
  }
}

class _RawHttpResponse {
  const _RawHttpResponse({required this.statusCode, required this.body});

  final int statusCode;
  final List<int> body;

  static _RawHttpResponse parse(List<int> bytes) {
    final separator = _findHeaderSeparator(bytes);
    if (separator == -1) {
      throw const RouterApiException(
          'Router returned an invalid HTTP response.');
    }

    final headerBytes = bytes.sublist(0, separator);
    final bodyStart = separator + 4;
    final lines = latin1.decode(headerBytes).split(RegExp(r'\r?\n'));
    final statusMatch = RegExp(r'^HTTP/\d(?:\.\d)?\s+(\d{3})(?:\s|$)')
        .firstMatch(lines.first.trim());
    if (statusMatch == null) {
      throw const RouterApiException('Router returned an invalid HTTP status.');
    }

    int? contentLength;
    var chunked = false;
    for (final line in lines.skip(1)) {
      final colon = line.indexOf(':');
      if (colon <= 0) {
        continue;
      }
      final name = line.substring(0, colon).trim().toLowerCase();
      final value = line.substring(colon + 1).trim();
      if (name == 'content-length') {
        contentLength = int.tryParse(value);
      } else if (name == 'transfer-encoding' &&
          value.toLowerCase().contains('chunked')) {
        chunked = true;
      }
    }

    var responseBody = bytes.sublist(bodyStart);
    if (chunked) {
      responseBody = _decodeChunkedBody(responseBody);
    } else if (contentLength != null && responseBody.length > contentLength) {
      responseBody = responseBody.sublist(0, contentLength);
    }

    return _RawHttpResponse(
      statusCode: int.parse(statusMatch.group(1)!),
      body: responseBody,
    );
  }

  static int _findHeaderSeparator(List<int> bytes) {
    for (var index = 0; index <= bytes.length - 4; index++) {
      if (bytes[index] == 13 &&
          bytes[index + 1] == 10 &&
          bytes[index + 2] == 13 &&
          bytes[index + 3] == 10) {
        return index;
      }
    }
    return -1;
  }

  static List<int> _decodeChunkedBody(List<int> bytes) {
    final decoded = <int>[];
    var offset = 0;
    while (offset < bytes.length) {
      final lineEnd = _findCrlf(bytes, offset);
      if (lineEnd == -1) {
        break;
      }
      final size = int.tryParse(
        latin1.decode(bytes.sublist(offset, lineEnd)).split(';').first.trim(),
        radix: 16,
      );
      if (size == null || size == 0) {
        break;
      }
      final dataStart = lineEnd + 2;
      final dataEnd = dataStart + size;
      if (dataEnd > bytes.length) {
        break;
      }
      decoded.addAll(bytes.sublist(dataStart, dataEnd));
      offset = dataEnd + 2;
    }
    return decoded;
  }

  static int _findCrlf(List<int> bytes, int start) {
    for (var index = start; index < bytes.length - 1; index++) {
      if (bytes[index] == 13 && bytes[index + 1] == 10) {
        return index;
      }
    }
    return -1;
  }
}

class RouterApiException implements Exception {
  const RouterApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
