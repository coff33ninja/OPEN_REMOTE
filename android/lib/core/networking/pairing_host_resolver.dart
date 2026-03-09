import 'dart:io';

import '../models/device.dart';
import '../models/pairing.dart';

List<PairingPayload> pairingHostCandidates(
  PairingPayload pairing,
  Iterable<Device> discoveredDevices, {
  bool preferLocalRoutes = true,
}) {
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

  final orderedNetworks = List<PairingNetworkOption>.from(
    pairing.availableNetworks,
  )..sort(
      (PairingNetworkOption left, PairingNetworkOption right) =>
          _networkPriority(
        right,
        preferLocalRoutes: preferLocalRoutes,
      ).compareTo(
        _networkPriority(
          left,
          preferLocalRoutes: preferLocalRoutes,
        ),
      ),
    );

  for (final option in orderedNetworks) {
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

int _networkPriority(
  PairingNetworkOption option, {
  required bool preferLocalRoutes,
}) {
  var score = 0;
  if (preferLocalRoutes && option.isLikelyLocal) {
    score += 400;
  }
  if (option.preferred) {
    score += preferLocalRoutes ? 120 : 300;
  }
  if (option.canWake) {
    score += preferLocalRoutes ? 100 : 20;
  }
  if (!preferLocalRoutes && option.isLikelyLocal) {
    score += 40;
  }
  if (option.kind == NetworkTransportKind.configured) {
    score -= 120;
  }
  if (option.kind == NetworkTransportKind.unknown) {
    score -= 10;
  }

  return score;
}
