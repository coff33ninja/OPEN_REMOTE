import '../models/device.dart';

List<NetworkRoute> deviceConnectionCandidates(
  Device device, {
  required bool preferLocalRoutes,
}) {
  final candidates = mergeNetworkRoutes(
    <NetworkRoute>[
      NetworkRoute(
        host: device.host,
        friendlyName: device.host,
        kind: inferNetworkKindFromHost(device.host),
        wakeTarget: device.wakeTarget,
      ),
      if ((device.preferredRouteHost ?? '').trim().isNotEmpty)
        NetworkRoute(
          host: device.preferredRouteHost!,
          friendlyName: device.preferredRouteHost!,
          kind: inferNetworkKindFromHost(device.preferredRouteHost!),
          preferred: true,
        ),
      if ((device.lastSuccessfulRouteHost ?? '').trim().isNotEmpty)
        NetworkRoute(
          host: device.lastSuccessfulRouteHost!,
          friendlyName: device.lastSuccessfulRouteHost!,
          kind: inferNetworkKindFromHost(device.lastSuccessfulRouteHost!),
        ),
    ],
    device.networkRoutes,
  ).toList(growable: true);

  candidates.sort(
    (NetworkRoute left, NetworkRoute right) => _routePriority(
      device,
      right,
      preferLocalRoutes: preferLocalRoutes,
    ).compareTo(
      _routePriority(
        device,
        left,
        preferLocalRoutes: preferLocalRoutes,
      ),
    ),
  );

  return candidates;
}

Device deviceWithRoute(
  Device device,
  NetworkRoute route, {
  bool markPreferred = false,
}) {
  return device.copyWith(
    host: route.host,
    wakeTarget: route.wakeTarget ?? device.wakeTarget,
    networkRoutes: mergeNetworkRoutes(
      <NetworkRoute>[route],
      device.networkRoutes,
    ),
    preferredRouteHost: markPreferred ? route.host : device.preferredRouteHost,
  );
}

int _routePriority(
  Device device,
  NetworkRoute route, {
  required bool preferLocalRoutes,
}) {
  var score = 0;
  final normalizedHost = route.host.trim().toLowerCase();

  if (preferLocalRoutes && route.isLikelyLocal) {
    score += 500;
  }
  if (route.canWake) {
    score += preferLocalRoutes ? 120 : 40;
  }
  if ((device.preferredRouteHost ?? '').trim().toLowerCase() ==
      normalizedHost) {
    score += preferLocalRoutes ? 160 : 400;
  }
  if ((device.lastSuccessfulRouteHost ?? '').trim().toLowerCase() ==
      normalizedHost) {
    score += preferLocalRoutes ? 100 : 220;
  }
  if (device.host.trim().toLowerCase() == normalizedHost) {
    score += 80;
  }
  if (route.preferred) {
    score += 40;
  }
  if (!preferLocalRoutes && route.isLikelyLocal) {
    score += 60;
  }
  if (route.kind == NetworkTransportKind.configured) {
    score -= 120;
  }
  if (route.kind == NetworkTransportKind.unknown) {
    score -= 20;
  }

  return score;
}
