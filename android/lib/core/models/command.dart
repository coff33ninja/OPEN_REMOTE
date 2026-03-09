class CommandEnvelope {
  const CommandEnvelope({
    required this.type,
    this.action,
    this.name,
    this.remoteId,
    this.requestId,
    this.arguments = const <String, dynamic>{},
  });

  final String type;
  final String? action;
  final String? name;
  final String? remoteId;
  final String? requestId;
  final Map<String, dynamic> arguments;

  String get commandName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    if (action != null && action!.isNotEmpty) {
      return '${type}_$action';
    }
    return type;
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'request_id': requestId,
      'remote_id': remoteId,
      'type': type,
      'action': action,
      'name': name,
      'arguments': arguments,
    }..removeWhere((String key, dynamic value) => value == null);
  }
}
