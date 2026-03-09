import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../core/models/remote_layout.dart';
import '../../ui/widgets/remote_button.dart';
import '../../ui/widgets/touchpad_surface.dart';

class CustomRemoteScreen extends StatelessWidget {
  const CustomRemoteScreen({
    super.key,
    required this.enabled,
    required this.remotes,
    required this.favoriteRemoteIds,
    required this.onSend,
    required this.onToggleFavoriteRemote,
    this.shrinkWrap = false,
    this.physics,
  });

  final bool enabled;
  final List<RemoteLayout> remotes;
  final Set<String> favoriteRemoteIds;
  final Future<void> Function(CommandEnvelope command) onSend;
  final Future<void> Function(RemoteLayout remote) onToggleFavoriteRemote;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (remotes.isEmpty) {
      return const Center(child: Text('No bundled remotes found.'));
    }

    return ListView(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.all(20),
      children: remotes
          .map(
            (RemoteLayout remote) => Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                remote.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(remote.category),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => onToggleFavoriteRemote(remote),
                          icon: Icon(
                            favoriteRemoteIds.contains(remote.id)
                                ? Icons.star
                                : Icons.star_border,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (remote.usesCanvas)
                      _RemoteCanvasView(
                        enabled: enabled,
                        remote: remote,
                        onSend: onSend,
                      )
                    else
                      ...remote.layout.map(
                        (RemoteControl control) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _RemoteControlView(
                            enabled: enabled,
                            remoteId: remote.id,
                            control: control,
                            onSend: onSend,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _RemoteControlView extends StatelessWidget {
  const _RemoteControlView({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
    this.canvasMode = false,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;
  final bool canvasMode;

  @override
  Widget build(BuildContext context) {
    switch (control.type) {
      case 'button':
      case 'toggle':
      case 'macro_button':
        final button = RemoteButton(
          label: control.label ?? control.command,
          enabled: enabled,
          onPressed: () => onSend(commandFromControl(remoteId, control)),
        );
        return canvasMode ? SizedBox.expand(child: button) : button;
      case 'slider':
        return _SliderControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
          canvasMode: canvasMode,
        );
      case 'text_input':
        return _TextInputControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
          canvasMode: canvasMode,
        );
      case 'touchpad':
        return _TouchpadControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
          canvasMode: canvasMode,
        );
      case 'dpad':
        return _DpadControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
          canvasMode: canvasMode,
        );
      case 'grid_buttons':
        return _GridButtonsControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
          canvasMode: canvasMode,
        );
      default:
        return Text('Unsupported control type: ${control.type}');
    }
  }
}

class _RemoteCanvasView extends StatelessWidget {
  const _RemoteCanvasView({
    required this.enabled,
    required this.remote,
    required this.onSend,
  });

  final bool enabled;
  final RemoteLayout remote;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    final canvas = remote.effectiveCanvas;
    final backgroundColor =
        _tryParseHexColor(canvas.backgroundColor) ?? const Color(0xFFF8FAFC);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        key: Key('remote-canvas-${remote.id}'),
        aspectRatio: canvas.width / canvas.height,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final scaleX = constraints.maxWidth / canvas.width;
            final scaleY = constraints.maxHeight / canvas.height;

            return DecoratedBox(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _CanvasGridPainter(
                          gridSpacingX: canvas.gridSize * scaleX,
                          gridSpacingY: canvas.gridSize * scaleY,
                        ),
                      ),
                    ),
                  ),
                  for (var index = 0; index < remote.layout.length; index++)
                    _buildPositionedControl(
                      remote.layout[index],
                      index,
                      scaleX,
                      scaleY,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPositionedControl(
    RemoteControl control,
    int index,
    double scaleX,
    double scaleY,
  ) {
    final frame = control.frame ??
        _fallbackFrameForRenderer(
          control,
          index,
          remote.effectiveCanvas,
        );

    return Positioned(
      left: frame.x * scaleX,
      top: frame.y * scaleY,
      width: frame.width * scaleX,
      height: frame.height * scaleY,
      child: _CanvasControlChrome(
        child: _RemoteControlView(
          enabled: enabled,
          remoteId: remote.id,
          control: control,
          onSend: onSend,
          canvasMode: true,
        ),
      ),
    );
  }
}

class _CanvasControlChrome extends StatelessWidget {
  const _CanvasControlChrome({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(24),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

class _CanvasGridPainter extends CustomPainter {
  const _CanvasGridPainter({
    required this.gridSpacingX,
    required this.gridSpacingY,
  });

  final double gridSpacingX;
  final double gridSpacingY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x140F172A)
      ..strokeWidth = 1;

    if (gridSpacingX > 0) {
      for (double x = gridSpacingX; x < size.width; x += gridSpacingX) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }

    if (gridSpacingY > 0) {
      for (double y = gridSpacingY; y < size.height; y += gridSpacingY) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasGridPainter oldDelegate) {
    return oldDelegate.gridSpacingX != gridSpacingX ||
        oldDelegate.gridSpacingY != gridSpacingY;
  }
}

CommandEnvelope commandFromControl(
  String remoteId,
  RemoteControl control, [
  Map<String, dynamic>? overrides,
]) {
  return commandFromBinding(
    remoteId: remoteId,
    commandName: control.command,
    props: control.props,
    overrides: overrides,
  );
}

CommandEnvelope commandFromBinding({
  required String remoteId,
  required String commandName,
  Map<String, dynamic> props = const <String, dynamic>{},
  Map<String, dynamic>? overrides,
}) {
  final parts = commandName.split('_');
  final type = parts.isNotEmpty ? parts.first : commandName;
  final action = parts.length > 1 ? parts.sublist(1).join('_') : null;

  final arguments = <String, dynamic>{}
    ..addAll(props)
    ..addAll(overrides ?? const <String, dynamic>{});

  return CommandEnvelope(
    type: type,
    action: action,
    name: commandName,
    remoteId: remoteId,
    arguments: arguments,
  );
}

CommandEnvelope _touchpadCommand(
  String remoteId,
  RemoteControl control, {
  required String commandKey,
  required String fallbackCommand,
  Map<String, dynamic> defaultProps = const <String, dynamic>{},
  Map<String, dynamic> overrides = const <String, dynamic>{},
}) {
  return commandFromBinding(
    remoteId: remoteId,
    commandName: _stringProp(control.props[commandKey]) ?? fallbackCommand,
    props: <String, dynamic>{
      ...defaultProps,
      ..._mapProp(control.props['${commandKey}_props']),
    },
    overrides: overrides,
  );
}

bool _boolProp(Map<String, dynamic> props, String key, bool fallback) {
  final value = props[key];
  if (value is bool) {
    return value;
  }
  if (value is String) {
    if (value.toLowerCase() == 'true') {
      return true;
    }
    if (value.toLowerCase() == 'false') {
      return false;
    }
  }
  return fallback;
}

double _doubleProp(Map<String, dynamic> props, String key, double fallback) {
  final value = props[key];
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

String? _stringProp(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

Map<String, dynamic> _mapProp(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic item) => MapEntry('$key', item),
    );
  }
  return const <String, dynamic>{};
}

class _SliderControl extends StatefulWidget {
  const _SliderControl({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
    required this.canvasMode,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;
  final bool canvasMode;

  @override
  State<_SliderControl> createState() => _SliderControlState();
}

class _SliderControlState extends State<_SliderControl> {
  late double _value;

  @override
  void initState() {
    super.initState();
    _value = widget.control.min ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final min = widget.control.min ?? 0;
    final max = widget.control.max ?? 100;
    final step = widget.control.step;
    final divisions = step != null && step > 0
        ? ((max - min) / step).round().clamp(1, 1000)
        : (max - min).round().clamp(1, 100);

    final slider = Slider(
      value: _value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: widget.enabled
          ? (double value) {
              setState(() {
                _value = value;
              });
            }
          : null,
      onChangeEnd: widget.enabled
          ? (double value) {
              widget.onSend(
                commandFromControl(
                  widget.remoteId,
                  widget.control,
                  <String, dynamic>{
                    'value': step == null || step >= 1 ? value.round() : value,
                  },
                ),
              );
            }
          : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.control.label ?? widget.control.command,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.canvasMode) const Spacer(),
        slider,
        if (widget.canvasMode)
          Text(
            _value.toStringAsFixed(step != null && step < 1 ? 1 : 0),
            style: Theme.of(context).textTheme.labelMedium,
          ),
      ],
    );
  }
}

class _TextInputControl extends StatefulWidget {
  const _TextInputControl({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
    required this.canvasMode,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;
  final bool canvasMode;

  @override
  State<_TextInputControl> createState() => _TextInputControlState();
}

class _TextInputControlState extends State<_TextInputControl> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _controller,
      enabled: widget.enabled,
      maxLines: widget.canvasMode ? null : 1,
      expands: widget.canvasMode,
      decoration: InputDecoration(
        labelText: widget.control.label ?? widget.control.command,
        border: const OutlineInputBorder(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.canvasMode) Expanded(child: field) else field,
        const SizedBox(height: 8),
        SizedBox(
          height: 48,
          child: RemoteButton(
            label: 'Send',
            enabled: widget.enabled,
            onPressed: () => widget.onSend(commandFromControl(
              widget.remoteId,
              widget.control,
              <String, dynamic>{'text': _controller.text},
            )),
          ),
        ),
      ],
    );
  }
}

class _TouchpadControl extends StatelessWidget {
  const _TouchpadControl({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
    required this.canvasMode,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;
  final bool canvasMode;

  @override
  Widget build(BuildContext context) {
    final child = TouchpadSurface(
      enabled: enabled,
      label: control.label ?? 'Touchpad',
      sensitivity: _doubleProp(control.props, 'sensitivity', 1.0),
      showScrollRail: _boolProp(control.props, 'show_scroll_rail', !canvasMode),
      showHints: !canvasMode,
      onMove: (Offset delta) => onSend(
        _touchpadCommand(
          remoteId,
          control,
          commandKey: 'move_command',
          fallbackCommand:
              control.command.isEmpty ? 'mouse_move' : control.command,
          overrides: <String, dynamic>{
            'dx': delta.dx.round(),
            'dy': delta.dy.round(),
          },
        ),
      ),
      onTap: () => onSend(
        _touchpadCommand(
          remoteId,
          control,
          commandKey: 'tap_command',
          fallbackCommand: 'mouse_click',
          defaultProps: const <String, dynamic>{'button': 'left'},
        ),
      ),
      onDoubleTap: () => onSend(
        _touchpadCommand(
          remoteId,
          control,
          commandKey: 'double_tap_command',
          fallbackCommand: 'mouse_double_click',
          defaultProps: const <String, dynamic>{'button': 'left'},
        ),
      ),
      onScroll: (int verticalSteps) => onSend(
        _touchpadCommand(
          remoteId,
          control,
          commandKey: 'scroll_command',
          fallbackCommand: 'mouse_scroll',
          overrides: <String, dynamic>{'vertical': verticalSteps},
        ),
      ),
      onButtonDown: (String button) => onSend(
        _touchpadCommand(
          remoteId,
          control,
          commandKey: 'button_down_command',
          fallbackCommand: 'mouse_button_down',
          defaultProps: <String, dynamic>{'button': button},
        ),
      ),
      onButtonUp: (String button) => onSend(
        _touchpadCommand(
          remoteId,
          control,
          commandKey: 'button_up_command',
          fallbackCommand: 'mouse_button_up',
          defaultProps: <String, dynamic>{'button': button},
        ),
      ),
    );

    if (canvasMode) {
      return SizedBox.expand(child: child);
    }

    return SizedBox(
      height: 160,
      child: child,
    );
  }
}

class _DpadControl extends StatelessWidget {
  const _DpadControl({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
    required this.canvasMode,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;
  final bool canvasMode;

  @override
  Widget build(BuildContext context) {
    final up = _bindingFromProp(control.props['up']);
    final down = _bindingFromProp(control.props['down']);
    final left = _bindingFromProp(control.props['left']);
    final right = _bindingFromProp(control.props['right']);
    final center = _bindingFromProp(control.props['center']);

    final pad = SizedBox(
      width: 220,
      height: 220,
      child: Column(
        children: <Widget>[
          _DirectionButton(
            enabled: enabled && up != null,
            icon: Icons.keyboard_arrow_up,
            label: up?.label ?? 'Up',
            onPressed: up == null ? null : () => onSend(up.toCommand(remoteId)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _DirectionButton(
                enabled: enabled && left != null,
                icon: Icons.keyboard_arrow_left,
                label: left?.label ?? 'Left',
                onPressed: left == null
                    ? null
                    : () => onSend(left.toCommand(remoteId)),
              ),
              const SizedBox(width: 12),
              _DirectionButton(
                enabled: enabled && center != null,
                icon: Icons.radio_button_checked,
                label: center?.label ?? 'Center',
                onPressed: center == null
                    ? null
                    : () => onSend(center.toCommand(remoteId)),
              ),
              const SizedBox(width: 12),
              _DirectionButton(
                enabled: enabled && right != null,
                icon: Icons.keyboard_arrow_right,
                label: right?.label ?? 'Right',
                onPressed: right == null
                    ? null
                    : () => onSend(right.toCommand(remoteId)),
              ),
            ],
          ),
          _DirectionButton(
            enabled: enabled && down != null,
            icon: Icons.keyboard_arrow_down,
            label: down?.label ?? 'Down',
            onPressed:
                down == null ? null : () => onSend(down.toCommand(remoteId)),
          ),
        ],
      ),
    );

    if (canvasMode) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if ((control.label ?? '').isNotEmpty) ...<Widget>[
            Text(
              control.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: pad,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(control.label ?? 'Directional pad'),
        const SizedBox(height: 12),
        Center(child: pad),
      ],
    );
  }
}

class _GridButtonsControl extends StatelessWidget {
  const _GridButtonsControl({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
    required this.canvasMode,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;
  final bool canvasMode;

  @override
  Widget build(BuildContext context) {
    final buttons = _buttonBindingsFromProp(control.props['buttons']);
    final columns =
        (control.props['columns'] as num?)?.toInt().clamp(1, 4) ?? 2;

    final grid = GridView.builder(
      shrinkWrap: !canvasMode,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: buttons.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (BuildContext context, int index) {
        final button = buttons[index];
        return RemoteButton(
          label: button.label,
          enabled: enabled,
          onPressed: () => onSend(button.toCommand(remoteId)),
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if ((control.label ?? '').isNotEmpty) ...<Widget>[
          Text(
            control.label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],
        if (canvasMode) Expanded(child: grid) else grid,
      ],
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.enabled,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final IconData icon;
  final String label;
  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandBinding {
  const _CommandBinding({
    required this.command,
    required this.label,
    this.props = const <String, dynamic>{},
  });

  final String command;
  final String label;
  final Map<String, dynamic> props;

  CommandEnvelope toCommand(String remoteId) {
    return commandFromBinding(
      remoteId: remoteId,
      commandName: command,
      props: props,
    );
  }
}

_CommandBinding? _bindingFromProp(dynamic raw) {
  if (raw is! Map) {
    return null;
  }

  final json = Map<String, dynamic>.from(raw);
  final command = json['command'] as String?;
  if (command == null || command.isEmpty) {
    return null;
  }

  return _CommandBinding(
    command: command,
    label: json['label'] as String? ?? command,
    props: Map<String, dynamic>.from(
      json['props'] as Map? ?? const <String, dynamic>{},
    ),
  );
}

List<_CommandBinding> _buttonBindingsFromProp(dynamic raw) {
  if (raw is! List) {
    return const <_CommandBinding>[];
  }

  return raw
      .map(_bindingFromProp)
      .whereType<_CommandBinding>()
      .toList(growable: false);
}

Color? _tryParseHexColor(String? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) {
    return null;
  }

  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  final parsed = int.tryParse(hex, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(parsed);
}

RemoteFrame _fallbackFrameForRenderer(
  RemoteControl control,
  int index,
  RemoteCanvas canvas,
) {
  final prototype = _defaultFrameForType(control.type);
  final spacing = canvas.gridSize;
  final perColumn = 3;
  final column = index % perColumn;
  final row = index ~/ perColumn;
  final left = spacing + (column * (prototype.width + spacing));
  final top = spacing + (row * (prototype.height + spacing));

  return prototype.copyWith(
    x: left.clamp(0.0, canvas.width - prototype.width).toDouble(),
    y: top.clamp(0.0, canvas.height - prototype.height).toDouble(),
  );
}

RemoteFrame _defaultFrameForType(String type) {
  switch (type) {
    case 'touchpad':
      return const RemoteFrame(x: 0, y: 0, width: 840, height: 340);
    case 'dpad':
      return const RemoteFrame(x: 0, y: 0, width: 420, height: 420);
    case 'grid_buttons':
      return const RemoteFrame(x: 0, y: 0, width: 720, height: 320);
    case 'text_input':
      return const RemoteFrame(x: 0, y: 0, width: 720, height: 180);
    case 'slider':
      return const RemoteFrame(x: 0, y: 0, width: 720, height: 120);
    case 'macro_button':
    case 'toggle':
    case 'button':
    default:
      return const RemoteFrame(x: 0, y: 0, width: 360, height: 120);
  }
}
