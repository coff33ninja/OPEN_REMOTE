class Device {
  const Device({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.serviceType,
    this.accessToken,
    this.websocketPath = '/ws',
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String serviceType;
  final String? accessToken;
  final String websocketPath;

  Uri get websocketUrl => Uri(
        scheme: 'ws',
        host: host,
        port: port,
        path: websocketPath,
      );

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String? ?? json['host'] as String? ?? 'unknown-device',
      name: json['name'] as String? ??
          json['device_name'] as String? ??
          'OpenRemote Agent',
      host: json['host'] as String? ?? '127.0.0.1',
      port: (json['port'] as num?)?.toInt() ?? 9876,
      serviceType: json['service_type'] as String? ?? '_openremote._tcp',
      accessToken: json['access_token'] as String?,
      websocketPath: json['websocket_path'] as String? ?? '/ws',
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
    };
  }

  Device copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? serviceType,
    String? accessToken,
    String? websocketPath,
  }) {
    return Device(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      serviceType: serviceType ?? this.serviceType,
      accessToken: accessToken ?? this.accessToken,
      websocketPath: websocketPath ?? this.websocketPath,
    );
  }
}
