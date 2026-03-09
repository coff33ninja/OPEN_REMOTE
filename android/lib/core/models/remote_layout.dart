class RemoteLayout {
  const RemoteLayout({
    required this.id,
    required this.name,
    required this.category,
    required this.layout,
    this.canvas,
  });

  final String id;
  final String name;
  final String category;
  final List<RemoteControl> layout;
  final RemoteCanvas? canvas;

  bool get usesCanvas {
    return canvas != null ||
        layout.any((RemoteControl control) {
          return control.frame != null;
        });
  }

  RemoteCanvas get effectiveCanvas {
    return canvas ?? RemoteCanvas.defaultCanvas;
  }

  factory RemoteLayout.fromJson(Map<String, dynamic> json) {
    final rawLayout = json['layout'] as List<dynamic>? ?? const <dynamic>[];

    return RemoteLayout(
      id: json['id'] as String? ?? 'remote',
      name: json['name'] as String? ?? 'Unnamed Remote',
      category: json['category'] as String? ?? 'general',
      canvas: json['canvas'] is Map<String, dynamic>
          ? RemoteCanvas.fromJson(json['canvas'] as Map<String, dynamic>)
          : json['canvas'] is Map
              ? RemoteCanvas.fromJson(
                  Map<String, dynamic>.from(json['canvas'] as Map),
                )
              : null,
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
      'canvas': canvas?.toJson(),
      'layout':
          layout.map((RemoteControl control) => control.toJson()).toList(),
    }..removeWhere((String key, dynamic value) => value == null);
  }

  RemoteLayout copyWith({
    String? id,
    String? name,
    String? category,
    List<RemoteControl>? layout,
    Object? canvas = _unset,
  }) {
    return RemoteLayout(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      layout: layout ?? this.layout,
      canvas: identical(canvas, _unset) ? this.canvas : canvas as RemoteCanvas?,
    );
  }
}

class RemoteCanvas {
  const RemoteCanvas({
    required this.width,
    required this.height,
    this.gridSize = 40,
    this.backgroundColor,
  });

  static const RemoteCanvas defaultCanvas = RemoteCanvas(
    width: 1000,
    height: 1600,
    gridSize: 40,
  );

  final double width;
  final double height;
  final double gridSize;
  final String? backgroundColor;

  factory RemoteCanvas.fromJson(Map<String, dynamic> json) {
    return RemoteCanvas(
      width: (json['width'] as num?)?.toDouble() ?? defaultCanvas.width,
      height: (json['height'] as num?)?.toDouble() ?? defaultCanvas.height,
      gridSize: (json['grid_size'] as num?)?.toDouble() ??
          (json['gridSize'] as num?)?.toDouble() ??
          defaultCanvas.gridSize,
      backgroundColor: json['background_color'] as String? ??
          json['backgroundColor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'width': width,
      'height': height,
      'grid_size': gridSize,
      'background_color': backgroundColor,
    }..removeWhere((String key, dynamic value) => value == null);
  }

  RemoteCanvas copyWith({
    double? width,
    double? height,
    double? gridSize,
    Object? backgroundColor = _unset,
  }) {
    return RemoteCanvas(
      width: width ?? this.width,
      height: height ?? this.height,
      gridSize: gridSize ?? this.gridSize,
      backgroundColor: identical(backgroundColor, _unset)
          ? this.backgroundColor
          : backgroundColor as String?,
    );
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
    this.frame,
  });

  final String id;
  final String type;
  final String command;
  final String? label;
  final double? min;
  final double? max;
  final double? step;
  final Map<String, dynamic> props;
  final RemoteFrame? frame;

  factory RemoteControl.fromJson(Map<String, dynamic> json) {
    final rawFrame = json['frame'];

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
      frame: rawFrame is Map<String, dynamic>
          ? RemoteFrame.fromJson(rawFrame)
          : rawFrame is Map
              ? RemoteFrame.fromJson(Map<String, dynamic>.from(rawFrame))
              : _frameFromLegacyFields(json),
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
      'frame': frame?.toJson(),
    }..removeWhere((String key, dynamic value) => value == null);
  }

  RemoteControl copyWith({
    String? id,
    String? type,
    String? command,
    Object? label = _unset,
    Object? min = _unset,
    Object? max = _unset,
    Object? step = _unset,
    Map<String, dynamic>? props,
    Object? frame = _unset,
  }) {
    return RemoteControl(
      id: id ?? this.id,
      type: type ?? this.type,
      command: command ?? this.command,
      label: identical(label, _unset) ? this.label : label as String?,
      min: identical(min, _unset) ? this.min : min as double?,
      max: identical(max, _unset) ? this.max : max as double?,
      step: identical(step, _unset) ? this.step : step as double?,
      props: props ?? this.props,
      frame: identical(frame, _unset) ? this.frame : frame as RemoteFrame?,
    );
  }
}

class RemoteFrame {
  const RemoteFrame({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  factory RemoteFrame.fromJson(Map<String, dynamic> json) {
    return RemoteFrame(
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 240,
      height: (json['height'] as num?)?.toDouble() ?? 120,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  RemoteFrame copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    return RemoteFrame(
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

RemoteFrame? _frameFromLegacyFields(Map<String, dynamic> json) {
  final x = (json['x'] as num?)?.toDouble();
  final y = (json['y'] as num?)?.toDouble();
  final width = (json['width'] as num?)?.toDouble();
  final height = (json['height'] as num?)?.toDouble();

  if (x == null || y == null || width == null || height == null) {
    return null;
  }

  return RemoteFrame(
    x: x,
    y: y,
    width: width,
    height: height,
  );
}

const Object _unset = Object();
