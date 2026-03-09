import 'dart:convert';

import 'device.dart';

class PairingNetworkOption {
  const PairingNetworkOption({
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

  factory PairingNetworkOption.fromJson(Map<String, dynamic> json) {
    final wakeTarget = _parseWakeTarget(json);
    return PairingNetworkOption(
      host: json['host'] as String? ?? '',
      name: json['name'] as String? ?? '',
      friendlyName: json['friendly_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      kind: json['kind'] as String? ??
          inferNetworkKindFromHost(
            json['host'] as String? ?? '',
          ),
      isVirtual: json['is_virtual'] as bool? ?? false,
      preferred: json['preferred'] as bool? ?? false,
      wakeTarget: wakeTarget?.isConfigured == true ? wakeTarget : null,
    );
  }

  NetworkRoute toNetworkRoute({bool preferred = false}) {
    return NetworkRoute(
      host: host,
      name: name,
      friendlyName: friendlyName,
      description: description,
      kind: kind,
      isVirtual: isVirtual,
      preferred: preferred || this.preferred,
      wakeTarget: wakeTarget,
    );
  }
}

class PairingPayload {
  const PairingPayload({
    required this.host,
    required this.port,
    required this.token,
    required this.deviceName,
    required this.serviceType,
    required this.websocketPath,
    this.wakeTarget,
    this.networkOptions = const <PairingNetworkOption>[],
  });

  final String host;
  final int port;
  final String token;
  final String deviceName;
  final String serviceType;
  final String websocketPath;
  final WakeTarget? wakeTarget;
  final List<PairingNetworkOption> networkOptions;

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
    final host = payload['host'] as String? ?? '127.0.0.1';
    final wakeTarget = _parseWakeTarget(payload);
    final networkOptions = _parseNetworkOptions(
      payload,
      fallbackHost: host,
      fallbackWakeTarget: wakeTarget,
    );

    return PairingPayload(
      host: host,
      port: (payload['port'] as num?)?.toInt() ?? 9876,
      token: payload['token'] as String? ?? '',
      deviceName: payload['device'] as String? ?? 'OpenRemote Agent',
      serviceType: payload['service'] as String? ?? '_openremote._tcp',
      websocketPath: payload['ws_path'] as String? ?? '/ws',
      wakeTarget: wakeTarget,
      networkOptions: networkOptions,
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
      wakeTarget: wakeTarget,
      networkRoutes: availableNetworks
          .map(
            (PairingNetworkOption option) => option.toNetworkRoute(
              preferred:
                  option.host.trim().toLowerCase() == host.trim().toLowerCase(),
            ),
          )
          .toList(growable: false),
      preferredRouteHost: host,
    );
  }

  PairingPayload copyWith({
    String? host,
    int? port,
    String? token,
    String? deviceName,
    String? serviceType,
    String? websocketPath,
    WakeTarget? wakeTarget,
    List<PairingNetworkOption>? networkOptions,
  }) {
    return PairingPayload(
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      deviceName: deviceName ?? this.deviceName,
      serviceType: serviceType ?? this.serviceType,
      websocketPath: websocketPath ?? this.websocketPath,
      wakeTarget: wakeTarget ?? this.wakeTarget,
      networkOptions: networkOptions ?? this.networkOptions,
    );
  }

  List<PairingNetworkOption> get availableNetworks {
    if (networkOptions.isEmpty) {
      return <PairingNetworkOption>[
        PairingNetworkOption(
          host: host,
          wakeTarget: wakeTarget,
        ),
      ];
    }

    final options = <PairingNetworkOption>[];
    final seenHosts = <String>{};
    void addOption(PairingNetworkOption option) {
      final normalizedHost = option.host.trim();
      if (normalizedHost.isEmpty) {
        return;
      }

      final dedupeKey = normalizedHost.toLowerCase();
      if (!seenHosts.add(dedupeKey)) {
        return;
      }

      options.add(option);
    }

    for (final PairingNetworkOption option in networkOptions) {
      addOption(option);
    }
    addOption(
      PairingNetworkOption(
        host: host,
        wakeTarget: wakeTarget,
      ),
    );

    return options;
  }

  PairingPayload selectNetwork(PairingNetworkOption option) {
    return withRoute(
      host: option.host,
      wakeTarget: option.wakeTarget,
      networkOptions: availableNetworks
          .map(
            (PairingNetworkOption existing) => PairingNetworkOption(
              host: existing.host,
              name: existing.name,
              friendlyName: existing.friendlyName,
              description: existing.description,
              kind: existing.kind,
              isVirtual: existing.isVirtual,
              preferred: existing.host.trim().toLowerCase() ==
                  option.host.trim().toLowerCase(),
              wakeTarget: existing.wakeTarget,
            ),
          )
          .toList(growable: false),
    );
  }

  PairingPayload withRoute({
    required String host,
    required WakeTarget? wakeTarget,
    List<PairingNetworkOption>? networkOptions,
  }) {
    return PairingPayload(
      host: host,
      port: port,
      token: token,
      deviceName: deviceName,
      serviceType: serviceType,
      websocketPath: websocketPath,
      wakeTarget: wakeTarget,
      networkOptions: networkOptions ?? this.networkOptions,
    );
  }
}

WakeTarget? _parseWakeTarget(Map<String, dynamic> json) {
  if (json['wake_mac'] == null && json['wake_broadcast'] == null) {
    return null;
  }

  final parsed = WakeTarget.fromJson(json);
  if (!parsed.isConfigured) {
    return null;
  }

  return parsed;
}

List<PairingNetworkOption> _parseNetworkOptions(
  Map<String, dynamic> payload, {
  required String fallbackHost,
  required WakeTarget? fallbackWakeTarget,
}) {
  final options = <PairingNetworkOption>[];
  final seenHosts = <String>{};

  void addOption(PairingNetworkOption option) {
    final normalizedHost = option.host.trim();
    if (normalizedHost.isEmpty) {
      return;
    }

    final dedupeKey = normalizedHost.toLowerCase();
    if (!seenHosts.add(dedupeKey)) {
      return;
    }

    options.add(
      PairingNetworkOption(
        host: normalizedHost,
        name: option.name,
        friendlyName: option.friendlyName,
        description: option.description,
        kind: option.kind,
        isVirtual: option.isVirtual,
        preferred: option.preferred,
        wakeTarget: option.wakeTarget,
      ),
    );
  }

  final rawNetworks = payload['networks'];
  if (rawNetworks is List) {
    for (final entry in rawNetworks) {
      if (entry is! Map) {
        continue;
      }

      addOption(
        PairingNetworkOption.fromJson(Map<String, dynamic>.from(entry)),
      );
    }
  }

  addOption(
    PairingNetworkOption(
      host: fallbackHost,
      wakeTarget: fallbackWakeTarget,
    ),
  );

  return options;
}
