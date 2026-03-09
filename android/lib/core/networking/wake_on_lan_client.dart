import 'dart:io';

import '../models/device.dart';

class WakeOnLanClient {
  const WakeOnLanClient();

  List<int> buildMagicPacket(String macAddress) {
    final macBytes = _parseMac(macAddress);
    return <int>[
      ...List<int>.filled(6, 0xFF),
      for (var repeat = 0; repeat < 16; repeat++) ...macBytes,
    ];
  }

  Future<void> send(WakeTarget wakeTarget) async {
    if (!wakeTarget.isConfigured) {
      throw const FormatException('Wake target is missing MAC or broadcast.');
    }

    final host = InternetAddress.tryParse(wakeTarget.broadcast);
    if (host == null) {
      throw FormatException(
        'Wake broadcast must be an IP address: ${wakeTarget.broadcast}',
      );
    }

    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    try {
      socket.broadcastEnabled = true;
      final packet = buildMagicPacket(wakeTarget.mac);
      socket.send(packet, host, wakeTarget.port);
    } finally {
      socket.close();
    }
  }

  List<int> _parseMac(String macAddress) {
    final normalized = macAddress
        .trim()
        .toUpperCase()
        .replaceAll('-', '')
        .replaceAll(':', '')
        .replaceAll('.', '');
    if (normalized.length != 12) {
      throw FormatException('Wake MAC must contain 12 hex digits: $macAddress');
    }

    final bytes = <int>[];
    for (var index = 0; index < normalized.length; index += 2) {
      final byte = int.tryParse(
        normalized.substring(index, index + 2),
        radix: 16,
      );
      if (byte == null) {
        throw FormatException('Wake MAC contains invalid hex: $macAddress');
      }
      bytes.add(byte);
    }
    return bytes;
  }
}
