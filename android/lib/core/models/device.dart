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
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String serviceType;
  final String? accessToken;
  final String websocketPath;
  final WakeTarget? wakeTarget;

  bool get canWake => wakeTarget?.isConfigured ?? false;

  Uri get websocketUrl => Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: websocketPath,
      );

  factory Device.fromJson(Map<String, dynamic> json) {
    WakeTarget? wakeTarget;
    final wakeTargetJson = json['wake_target'];
    if (wakeTargetJson is Map) {
      final parsed =
          WakeTarget.fromJson(Map<String, dynamic>.from(wakeTargetJson));
      if (parsed.isConfigured) {
        wakeTarget = parsed;
      }
    } else if (json['wake_mac'] != null || json['wake_broadcast'] != null) {
      final parsed = WakeTarget.fromJson(json);
      if (parsed.isConfigured) {
        wakeTarget = parsed;
      }
    }

    return Device(
      id: json['id'] as String? ??
          json['host'] as String? ??
          json['public_host'] as String? ??
          'unknown-device',
      name: json['name'] as String? ??
          json['device_name'] as String? ??
          'OpenRemote Agent',
      host: json['host'] as String? ??
          json['public_host'] as String? ??
          '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 9876,
      serviceType: json['service_type'] as String? ?? '_openremote._tcp',
      accessToken: json['access_token'] as String?,
      websocketPath: json['websocket_path'] as String? ?? '/ws',
      wakeTarget: wakeTarget,
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
    );
  }
}
