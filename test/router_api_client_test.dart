import 'dart:convert';
import 'dart:io';

import 'package:cell_tuner/router/router_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads router JSON when a response header is malformed', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final responseBody = jsonEncode(<String, String>{
      'SINR': '-3',
      'RSRP': '-103',
      'network_type_str': '4G LTE',
    });
    final response = 'HTTP/1.1 200 OK\r\n"broken-header\r\n'
        'Content-Length: ${utf8.encode(responseBody).length}\r\n\r\n'
        '$responseBody';
    final connection = server.first.then((socket) async {
      socket.write(response);
      await socket.flush();
      await socket.close();
    });

    try {
      final snapshot = await RouterApiClient(
        host: InternetAddress.loopbackIPv4.address,
        port: server.port,
      ).fetchSnapshot();

      expect(snapshot.networkType, '4G LTE');
      expect(snapshot.metrics[1].lte, '-3');
      expect(snapshot.metrics[2].lte, '-103');
      await connection;
    } finally {
      await server.close();
    }
  });
}
