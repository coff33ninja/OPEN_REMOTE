import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/pairing.dart';

void main() {
  test('PairingPayload parses openremote pair URI', () {
    final encoded = base64Url.encode(
      utf8.encode(
        jsonEncode(
          <String, dynamic>{
            'host': '127.0.0.1',
            'port': 9876,
            'token': 'abcd',
            'device': 'Workstation',
            'service': '_openremote._tcp',
            'ws_path': '/ws',
            'wake_mac': 'AA:BB:CC:DD:EE:FF',
            'wake_broadcast': '192.168.1.255',
            'wake_port': 9,
          },
        ),
      ),
    );
    final payload = PairingPayload.fromUri(
      'openremote://pair?data=$encoded',
    );

    expect(payload.host, '127.0.0.1');
    expect(payload.port, 9876);
    expect(payload.token, 'abcd');
    expect(payload.deviceName, 'Workstation');
    expect(payload.websocketPath, '/ws');
    expect(payload.wakeTarget?.mac, 'AA:BB:CC:DD:EE:FF');
    expect(payload.wakeTarget?.broadcast, '192.168.1.255');
  });
}
