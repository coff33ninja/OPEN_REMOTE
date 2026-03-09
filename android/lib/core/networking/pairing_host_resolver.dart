import 'dart:io';

import '../models/device.dart';
import '../models/pairing.dart';

List<PairingPayload> pairingHostCandidates(
  PairingPayload pairing,
  Iterable<Device> discoveredDevices,
) {
  final candidates = <PairingPayload>[];
  final seenHosts = <String>{};

  void addCandidate(
    String host, {
    WakeTarget? wakeTarget,
  }) {
    final normalized = host.trim();
    if (normalized.isEmpty) {
      return;
    }

    final dedupeKey = normalized.toLowerCase();
    if (!seenHosts.add(dedupeKey)) {
      return;
    }

    candidates.add(
      pairing.withRoute(
        host: normalized,
        wakeTarget: wakeTarget,
      ),
    );
  }

  for (final option in pairing.availableNetworks) {
    addCandidate(
      option.host,
      wakeTarget: option.wakeTarget,
    );

    if (!_isLiteralIp(option.host) && !option.host.contains('.')) {
      addCandidate(
        '${option.host}.local',
        wakeTarget: option.wakeTarget,
      );
    }
  }

  final expectedName = pairing.deviceName.trim().toLowerCase();
  for (final device in discoveredDevices) {
    if (device.port != pairing.port) {
      continue;
    }
    if (device.name.trim().toLowerCase() != expectedName) {
      continue;
    }

    addCandidate(device.host);
  }

  return candidates;
}

bool _isLiteralIp(String host) => InternetAddress.tryParse(host.trim()) != null;
