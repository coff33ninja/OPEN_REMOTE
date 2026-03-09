import 'dart:convert';

import 'device.dart';

class PairingPayload {
  const PairingPayload({
    required this.host,
    required this.port,
    required this.token,
    required this.deviceName,
    required this.serviceType,
    required this.websocketPath,
  });

  final String host;
  final int port;
  final String token;
  final String deviceName;
  final String serviceType;
  final String websocketPath;

  factory PairingPayload.fromUri(String rawUri) {
    final uri = Uri.parse(rawUri.trim());
    if (uri.scheme != 'openremote' || uri.host != 'pair') {
      throw const FormatException('Pair URI must use openremote://pair');
    }

    final encoded = uri.queryParameters['data'];
    if (encoded == null || encoded.isEmpty) {
      throw const FormatException('Pair URI is missing payload data');
    }

    final decoded = base64Url.decode(base64Url.normalize(encoded));
    final payload = jsonDecode(utf8.decode(decoded)) as Map<String, dynamic>;

    return PairingPayload(
      host: payload['host'] as String? ?? '127.0.0.1',
      port: (payload['port'] as num?)?.toInt() ?? 9876,
      token: payload['token'] as String? ?? '',
      deviceName: payload['device'] as String? ?? 'OpenRemote Agent',
      serviceType: payload['service'] as String? ?? '_openremote._tcp',
      websocketPath: payload['ws_path'] as String? ?? '/ws',
    );
  }

  Device toDevice({String? accessToken}) {
    return Device(
      id: '$host:$port',
      name: deviceName,
      host: host,
      port: port,
      serviceType: serviceType,
      accessToken: accessToken,
      websocketPath: websocketPath,
    );
  }
}
