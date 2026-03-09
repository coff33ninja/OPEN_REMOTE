class WakeTarget {
  const WakeTarget({
    required this.mac,
    required this.broadcast,
    this.port = 9,
  });

  final String mac;
  final String broadcast;
  final int port;

  bool get isConfigured => mac.trim().isNotEmpty && broadcast.trim().isNotEmpty;

  factory WakeTarget.fromJson(Map<String, dynamic> json) {
    final rawPort = json['port'] ?? json['wake_port'];
    return WakeTarget(
      mac: json['mac'] as String? ?? json['wake_mac'] as String? ?? '',
      broadcast: json['broadcast'] as String? ??
          json['wake_broadcast'] as String? ??
          json['wake_host'] as String? ??
          '',
      port: rawPort is num ? rawPort.toInt() : int.tryParse('$rawPort') ?? 9,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'mac': mac,
      'broadcast': broadcast,
      'port': port,
    };
  }

  WakeTarget copyWith({
    String? mac,
    String? broadcast,
    int? port,
  }) {
    return WakeTarget(
      mac: mac ?? this.mac,
      broadcast: broadcast ?? this.broadcast,
      port: port ?? this.port,
    );
  }
}

class NetworkTransportKind {
  static const String ethernet = 'ethernet';
  static const String wifi = 'wifi';
  static const String vpn = 'vpn';
  static const String virtualAdapter = 'virtual';
  static const String usb = 'usb';
  static const String configured = 'configured';
  static const String unknown = 'unknown';
}

class NetworkRoute {
  const NetworkRoute({
    required this.host,
    this.name = '',
    this.friendlyName = '',
    this.description = '',
    this.kind = NetworkTransportKind.unknown,
    this.isVirtual = false,
    this.preferred = false,
    this.wakeTarget,
  });

  final String host;
  final String name;
  final String friendlyName;
  final String description;
  final String kind;
  final bool isVirtual;
  final bool preferred;
  final WakeTarget? wakeTarget;

  bool get canWake => wakeTarget?.isConfigured ?? false;

  bool get isLikelyLocal =>
      canWake ||
      kind == NetworkTransportKind.ethernet ||
      kind == NetworkTransportKind.wifi ||
      kind == NetworkTransportKind.usb;

  String get displayName {
    if (friendlyName.trim().isNotEmpty) {
      return friendlyName;
    }
    if (name.trim().isNotEmpty) {
      return name;
    }
    return host;
  }

  String get kindLabel => networkTransportLabel(kind);

  factory NetworkRoute.fromJson(Map<String, dynamic> json) {
    final wakeTarget = _parseWakeTarget(json);
    return NetworkRoute(
      host: json['host'] as String? ?? '',
      name: json['name'] as String? ?? '',
      friendlyName: json['friendly_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      kind: json['kind'] as String? ?? NetworkTransportKind.unknown,
      isVirtual: json['is_virtual'] as bool? ?? false,
      preferred: json['preferred'] as bool? ?? false,
      wakeTarget: wakeTarget?.isConfigured == true ? wakeTarget : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'host': host,
      'name': name,
      'friendly_name': friendlyName,
      'description': description,
      'kind': kind,
      'is_virtual': isVirtual,
      'preferred': preferred,
      'wake_target': wakeTarget?.toJson(),
    }..removeWhere((String key, dynamic value) {
        if (value == null) {
          return true;
        }
        return value is String && value.isEmpty;
      });
  }

  NetworkRoute copyWith({
    String? host,
    String? name,
    String? friendlyName,
    String? description,
    String? kind,
    bool? isVirtual,
    bool? preferred,
    WakeTarget? wakeTarget,
  }) {
    return NetworkRoute(
      host: host ?? this.host,
      name: name ?? this.name,
      friendlyName: friendlyName ?? this.friendlyName,
      description: description ?? this.description,
      kind: kind ?? this.kind,
      isVirtual: isVirtual ?? this.isVirtual,
      preferred: preferred ?? this.preferred,
      wakeTarget: wakeTarget ?? this.wakeTarget,
    );
  }
}

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.serviceType,
    this.accessToken,
    this.websocketPath = '/ws',
    this.wakeTarget,
    this.networkRoutes = const <NetworkRoute>[],
    this.preferredRouteHost,
    this.lastSuccessfulRouteHost,
    this.lastSeenAt,
    this.lastConnectedAt,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String serviceType;
  final String? accessToken;
  final String websocketPath;
  final WakeTarget? wakeTarget;
  final List<NetworkRoute> networkRoutes;
  final String? preferredRouteHost;
  final String? lastSuccessfulRouteHost;
  final DateTime? lastSeenAt;
  final DateTime? lastConnectedAt;

  bool get canWake =>
      currentRoute?.canWake == true || wakeTarget?.isConfigured == true;

  bool get hasWakeRoute =>
      canWake || networkRoutes.any((NetworkRoute route) => route.canWake);

  Uri get websocketUrl => Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: websocketPath,
      );

  NetworkRoute? routeForHost(String routeHost) {
    final normalizedHost = routeHost.trim().toLowerCase();
    for (final NetworkRoute route in networkRoutes) {
      if (route.host.trim().toLowerCase() == normalizedHost) {
        return route;
      }
    }
    return null;
  }

  NetworkRoute? get currentRoute => routeForHost(host);

  NetworkRoute? get preferredRoute {
    final routeHost = preferredRouteHost;
    if (routeHost == null || routeHost.trim().isEmpty) {
      return null;
    }
    return routeForHost(routeHost);
  }

  NetworkRoute? get lastSuccessfulRoute {
    final routeHost = lastSuccessfulRouteHost;
    if (routeHost == null || routeHost.trim().isEmpty) {
      return null;
    }
    return routeForHost(routeHost);
  }

  factory Device.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as String? ??
        json['public_host'] as String? ??
        '127.0.0.1';
    final wakeTarget = _parseWakeTarget(json);
    final routes = _parseNetworkRoutes(
      json,
      fallbackHost: host,
      fallbackWakeTarget: wakeTarget,
    );

    return Device(
      id: json['id'] as String? ??
          json['public_host'] as String? ??
          'unknown-device',
      name: json['name'] as String? ??
          json['device_name'] as String? ??
          'OpenRemote Agent',
      host: host,
      port: (json['port'] as num?)?.toInt() ?? 9876,
      serviceType: json['service_type'] as String? ?? '_openremote._tcp',
      accessToken: json['access_token'] as String?,
      websocketPath: json['websocket_path'] as String? ?? '/ws',
      wakeTarget: wakeTarget?.isConfigured == true ? wakeTarget : null,
      networkRoutes: routes,
      preferredRouteHost: json['preferred_route_host'] as String?,
      lastSuccessfulRouteHost: json['last_successful_route_host'] as String?,
      lastSeenAt: _parseTimestamp(json['last_seen_at']),
      lastConnectedAt: _parseTimestamp(json['last_connected_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'service_type': serviceType,
      'access_token': accessToken,
      'websocket_path': websocketPath,
      'wake_target': wakeTarget?.toJson(),
      'networks': networkRoutes
          .map((NetworkRoute route) => route.toJson())
          .toList(growable: false),
      'preferred_route_host': preferredRouteHost,
      'last_successful_route_host': lastSuccessfulRouteHost,
      'last_seen_at': lastSeenAt?.toUtc().toIso8601String(),
      'last_connected_at': lastConnectedAt?.toUtc().toIso8601String(),
    }..removeWhere((String key, dynamic value) => value == null);
  }

  Device copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? serviceType,
    String? accessToken,
    String? websocketPath,
    WakeTarget? wakeTarget,
    List<NetworkRoute>? networkRoutes,
    String? preferredRouteHost,
    bool clearPreferredRouteHost = false,
    String? lastSuccessfulRouteHost,
    bool clearLastSuccessfulRouteHost = false,
    DateTime? lastSeenAt,
    bool clearLastSeenAt = false,
    DateTime? lastConnectedAt,
    bool clearLastConnectedAt = false,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      serviceType: serviceType ?? this.serviceType,
      accessToken: accessToken ?? this.accessToken,
      websocketPath: websocketPath ?? this.websocketPath,
      wakeTarget: wakeTarget ?? this.wakeTarget,
      networkRoutes: networkRoutes ?? this.networkRoutes,
      preferredRouteHost: clearPreferredRouteHost
          ? null
          : preferredRouteHost ?? this.preferredRouteHost,
      lastSuccessfulRouteHost: clearLastSuccessfulRouteHost
          ? null
          : lastSuccessfulRouteHost ?? this.lastSuccessfulRouteHost,
      lastSeenAt: clearLastSeenAt ? null : lastSeenAt ?? this.lastSeenAt,
      lastConnectedAt:
          clearLastConnectedAt ? null : lastConnectedAt ?? this.lastConnectedAt,
    );
  }
}

WakeTarget? _parseWakeTarget(Map<String, dynamic> json) {
  final wakeTargetJson = json['wake_target'];
  if (wakeTargetJson is Map) {
    final parsed =
        WakeTarget.fromJson(Map<String, dynamic>.from(wakeTargetJson));
    if (parsed.isConfigured) {
      return parsed;
    }
  } else if (json['wake_mac'] != null || json['wake_broadcast'] != null) {
    final parsed = WakeTarget.fromJson(json);
    if (parsed.isConfigured) {
      return parsed;
    }
  }

  return null;
}

List<NetworkRoute> _parseNetworkRoutes(
  Map<String, dynamic> json, {
  required String fallbackHost,
  required WakeTarget? fallbackWakeTarget,
}) {
  final routes = <NetworkRoute>[];
  final seenHosts = <String>{};

  void addRoute(NetworkRoute route) {
    final normalizedHost = route.host.trim();
    if (normalizedHost.isEmpty) {
      return;
    }

    final dedupeKey = normalizedHost.toLowerCase();
    if (!seenHosts.add(dedupeKey)) {
      return;
    }

    routes.add(route.copyWith(host: normalizedHost));
  }

  final rawNetworks = json['networks'];
  if (rawNetworks is List) {
    for (final dynamic entry in rawNetworks) {
      if (entry is! Map) {
        continue;
      }

      addRoute(NetworkRoute.fromJson(Map<String, dynamic>.from(entry)));
    }
  }

  addRoute(
    NetworkRoute(
      host: fallbackHost,
      friendlyName: fallbackHost,
      kind: inferNetworkKindFromHost(fallbackHost),
      wakeTarget: fallbackWakeTarget,
    ),
  );

  return routes;
}

DateTime? _parseTimestamp(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }

  return DateTime.tryParse(value)?.toUtc();
}

String networkTransportLabel(String kind) {
  switch (kind) {
    case NetworkTransportKind.ethernet:
      return 'Ethernet';
    case NetworkTransportKind.wifi:
      return 'Wi-Fi';
    case NetworkTransportKind.vpn:
      return 'VPN';
    case NetworkTransportKind.virtualAdapter:
      return 'Virtual';
    case NetworkTransportKind.usb:
      return 'USB';
    case NetworkTransportKind.configured:
      return 'Configured';
    default:
      return 'Network';
  }
}

String inferNetworkKindFromHost(String host) {
  final trimmedHost = host.trim();
  if (trimmedHost.startsWith('100.') || trimmedHost.startsWith('fd7a:')) {
    return NetworkTransportKind.vpn;
  }
  return NetworkTransportKind.unknown;
}

List<NetworkRoute> mergeNetworkRoutes(
  Iterable<NetworkRoute> primary,
  Iterable<NetworkRoute> secondary,
) {
  final merged = <String, NetworkRoute>{};

  void addRoutes(Iterable<NetworkRoute> routes) {
    for (final NetworkRoute route in routes) {
      final normalizedHost = route.host.trim().toLowerCase();
      if (normalizedHost.isEmpty) {
        continue;
      }

      final existing = merged[normalizedHost];
      if (existing == null) {
        merged[normalizedHost] = route;
        continue;
      }

      merged[normalizedHost] = existing.copyWith(
        name: route.name.isEmpty ? existing.name : route.name,
        friendlyName: route.friendlyName.isEmpty
            ? existing.friendlyName
            : route.friendlyName,
        description: route.description.isEmpty
            ? existing.description
            : route.description,
        kind: route.kind == NetworkTransportKind.unknown
            ? existing.kind
            : route.kind,
        isVirtual: existing.isVirtual || route.isVirtual,
        preferred: existing.preferred || route.preferred,
        wakeTarget: route.wakeTarget ?? existing.wakeTarget,
      );
    }
  }

  addRoutes(primary);
  addRoutes(secondary);

  return merged.values.toList(growable: false);
}
