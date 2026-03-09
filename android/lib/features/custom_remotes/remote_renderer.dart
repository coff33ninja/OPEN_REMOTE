import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../core/models/remote_layout.dart';
import '../../ui/widgets/remote_button.dart';

class CustomRemoteScreen extends StatelessWidget {
  const CustomRemoteScreen({
    super.key,
    required this.enabled,
    required this.remotes,
    required this.favoriteRemoteIds,
    required this.onSend,
    required this.onToggleFavoriteRemote,
  });

  final bool enabled;
  final List<RemoteLayout> remotes;
  final Set<String> favoriteRemoteIds;
  final Future<void> Function(CommandEnvelope command) onSend;
  final Future<void> Function(RemoteLayout remote) onToggleFavoriteRemote;

  @override
  Widget build(BuildContext context) {
    if (remotes.isEmpty) {
      return const Center(child: Text('No bundled remotes found.'));
    }

    return ListView(
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
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    switch (control.type) {
      case 'button':
      case 'toggle':
      case 'macro_button':
        return RemoteButton(
          label: control.label ?? control.command,
          enabled: enabled,
          onPressed: () => onSend(commandFromControl(remoteId, control)),
        );
      case 'slider':
        return _SliderControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
        );
      case 'text_input':
        return _TextInputControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
        );
      case 'touchpad':
        return _TouchpadControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
        );
      case 'dpad':
        return _DpadControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
        );
      case 'grid_buttons':
        return _GridButtonsControl(
          enabled: enabled,
          remoteId: remoteId,
          control: control,
          onSend: onSend,
        );
      default:
        return Text('Unsupported control type: ${control.type}');
    }
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

class _SliderControl extends StatefulWidget {
  const _SliderControl({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(widget.control.label ?? widget.control.command),
        Slider(
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
                        'value':
                            step == null || step >= 1 ? value.round() : value,
                      },
                    ),
                  );
                }
              : null,
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
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _controller,
          enabled: widget.enabled,
          decoration: InputDecoration(
            labelText: widget.control.label ?? widget.control.command,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        RemoteButton(
          label: 'Send',
          enabled: widget.enabled,
          onPressed: () => widget.onSend(commandFromControl(
            widget.remoteId,
            widget.control,
            <String, dynamic>{'text': _controller.text},
          )),
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
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: GestureDetector(
        onPanUpdate: enabled
            ? (DragUpdateDetails details) {
                onSend(
                  CommandEnvelope(
                    type: 'mouse',
                    action: 'move',
                    name: control.command,
                    remoteId: remoteId,
                    arguments: <String, dynamic>{
                      'dx': details.delta.dx.round(),
                      'dy': details.delta.dy.round(),
                    },
                  ),
                );
              }
            : null,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(control.label ?? 'Touchpad'),
          ),
        ),
      ),
    );
  }
}

class _DpadControl extends StatelessWidget {
  const _DpadControl({
    required this.enabled,
    required this.remoteId,
    required this.control,
    required this.onSend,
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    final up = _bindingFromProp(control.props['up']);
    final down = _bindingFromProp(control.props['down']);
    final left = _bindingFromProp(control.props['left']);
    final right = _bindingFromProp(control.props['right']);
    final center = _bindingFromProp(control.props['center']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(control.label ?? 'Directional pad'),
        const SizedBox(height: 12),
        Center(
          child: SizedBox(
            width: 220,
            child: Column(
              children: <Widget>[
                _DirectionButton(
                  enabled: enabled && up != null,
                  icon: Icons.keyboard_arrow_up,
                  label: up?.label ?? 'Up',
                  onPressed:
                      up == null ? null : () => onSend(up.toCommand(remoteId)),
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
                  onPressed: down == null
                      ? null
                      : () => onSend(down.toCommand(remoteId)),
                ),
              ],
            ),
          ),
        ),
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
  });

  final bool enabled;
  final String remoteId;
  final RemoteControl control;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    final buttons = _buttonBindingsFromProp(control.props['buttons']);
    final columns =
        (control.props['columns'] as num?)?.toInt().clamp(1, 4) ?? 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if ((control.label ?? '').isNotEmpty) ...<Widget>[
          Text(control.label!),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
        ),
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
