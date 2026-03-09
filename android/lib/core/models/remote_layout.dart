class RemoteLayout {
  const RemoteLayout({
    required this.id,
    required this.name,
    required this.category,
    required this.layout,
  });

  final String id;
  final String name;
  final String category;
  final List<RemoteControl> layout;

  factory RemoteLayout.fromJson(Map<String, dynamic> json) {
    final rawLayout = json['layout'] as List<dynamic>? ?? const <dynamic>[];

    return RemoteLayout(
      id: json['id'] as String? ?? 'remote',
      name: json['name'] as String? ?? 'Unnamed Remote',
      category: json['category'] as String? ?? 'general',
      layout: rawLayout
          .map((dynamic item) =>
              RemoteControl.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'category': category,
      'layout':
          layout.map((RemoteControl control) => control.toJson()).toList(),
    };
  }
}

class RemoteControl {
  const RemoteControl({
    required this.id,
    required this.type,
    required this.command,
    this.label,
    this.min,
    this.max,
    this.step,
    this.props = const <String, dynamic>{},
  });

  final String id;
  final String type;
  final String command;
  final String? label;
  final double? min;
  final double? max;
  final double? step;
  final Map<String, dynamic> props;

  factory RemoteControl.fromJson(Map<String, dynamic> json) {
    return RemoteControl(
      id: json['id'] as String? ?? 'control',
      type: json['type'] as String? ?? 'button',
      command: json['command'] as String? ?? 'noop',
      label: json['label'] as String?,
      min: (json['min'] as num?)?.toDouble(),
      max: (json['max'] as num?)?.toDouble(),
      step: (json['step'] as num?)?.toDouble(),
      props: Map<String, dynamic>.from(
          json['props'] as Map? ?? const <String, dynamic>{}),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'command': command,
      'label': label,
      'min': min,
      'max': max,
      'step': step,
      'props': props,
    }..removeWhere((String key, dynamic value) => value == null);
  }
}
