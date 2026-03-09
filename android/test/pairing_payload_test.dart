import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/pairing.dart';

void main() {
  test('PairingPayload parses openremote pair URI', () {
    final payload = PairingPayload.fromUri(
      'openremote://pair?data=eyJob3N0IjoiMTI3LjAuMC4xIiwicG9ydCI6OTg3NiwidG9rZW4iOiJhYmNkIiw'
      'iZGV2aWNlIjoiV29ya3N0YXRpb24iLCJzZXJ2aWNlIjoiX29wZW5yZW1vdGUuX3RjcCIsIndzX3BhdGgiOiIvd3MifQ',
    );

    expect(payload.host, '127.0.0.1');
    expect(payload.port, 9876);
    expect(payload.token, 'abcd');
    expect(payload.deviceName, 'Workstation');
    expect(payload.websocketPath, '/ws');
  });
}
