import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../ui/widgets/remote_button.dart';
import '../../ui/widgets/touchpad_surface.dart';

class MouseScreen extends StatefulWidget {
  const MouseScreen({
    super.key,
    required this.enabled,
    required this.onSend,
  });

  final bool enabled;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  State<MouseScreen> createState() => _MouseScreenState();
}

class _MouseScreenState extends State<MouseScreen> {
  static const String _remoteId = 'mouse-touchpad';

  double _sensitivity = 1.1;
  bool _dragLocked = false;

  @override
  void dispose() {
    if (_dragLocked) {
      unawaited(
        widget.onSend(
          const CommandEnvelope(
            type: 'mouse',
            action: 'button_up',
            remoteId: _remoteId,
            arguments: <String, dynamic>{'button': 'left'},
          ),
        ),
      );
    }
    super.dispose();
  }

  Future<void> _sendMouse({
    required String action,
    Map<String, dynamic> arguments = const <String, dynamic>{},
  }) {
    return widget.onSend(
      CommandEnvelope(
        type: 'mouse',
        action: action,
        remoteId: _remoteId,
        arguments: arguments,
      ),
    );
  }

  Future<void> _toggleDragLock() async {
    if (!widget.enabled) {
      return;
    }

    if (_dragLocked) {
      await _sendMouse(
        action: 'button_up',
        arguments: const <String, dynamic>{'button': 'left'},
      );
      if (mounted) {
        setState(() {
          _dragLocked = false;
        });
      }
      return;
    }

    await _sendMouse(
      action: 'button_down',
      arguments: const <String, dynamic>{'button': 'left'},
    );
    if (mounted) {
      setState(() {
        _dragLocked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.enabled
                ? 'Tap to click, double tap to double-click, hold to drag, and use the scroll rail for wheel input.'
                : 'Connect to an agent first.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TouchpadSurface(
              enabled: widget.enabled,
              label: _dragLocked ? 'Drag Locked' : 'Touchpad',
              sensitivity: _sensitivity,
              allowTapClick: !_dragLocked,
              enableHoldDrag: !_dragLocked,
              onMove: (Offset delta) => _sendMouse(
                action: 'move',
                arguments: <String, dynamic>{
                  'dx': delta.dx.round(),
                  'dy': delta.dy.round(),
                },
              ),
              onTap: () => _sendMouse(
                action: 'click',
                arguments: const <String, dynamic>{'button': 'left'},
              ),
              onSecondaryTap: () => _sendMouse(
                action: 'click',
                arguments: const <String, dynamic>{'button': 'right'},
              ),
              onDoubleTap: () => _sendMouse(
                action: 'double_click',
                arguments: const <String, dynamic>{'button': 'left'},
              ),
              onScroll: (int verticalSteps) => _sendMouse(
                action: 'scroll',
                arguments: <String, dynamic>{'vertical': verticalSteps},
              ),
              onButtonDown: (String button) => _sendMouse(
                action: 'button_down',
                arguments: <String, dynamic>{'button': button},
              ),
              onButtonUp: (String button) => _sendMouse(
                action: 'button_up',
                arguments: <String, dynamic>{'button': button},
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sensitivity ${_sensitivity.toStringAsFixed(1)}x',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Slider(
            value: _sensitivity,
            min: 0.6,
            max: 2.2,
            divisions: 8,
            label: '${_sensitivity.toStringAsFixed(1)}x',
            onChanged: widget.enabled
                ? (double value) {
                    setState(() {
                      _sensitivity = value;
                    });
                  }
                : null,
          ),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              RemoteButton(
                label: 'Left Click',
                enabled: widget.enabled,
                onPressed: () => _sendMouse(
                  action: 'click',
                  arguments: const <String, dynamic>{'button': 'left'},
                ),
              ),
              RemoteButton(
                label: 'Right Click',
                enabled: widget.enabled,
                onPressed: () => _sendMouse(
                  action: 'click',
                  arguments: const <String, dynamic>{'button': 'right'},
                ),
              ),
              RemoteButton(
                label: 'Middle Click',
                enabled: widget.enabled,
                onPressed: () => _sendMouse(
                  action: 'click',
                  arguments: const <String, dynamic>{'button': 'middle'},
                ),
              ),
              RemoteButton(
                label: 'Double Click',
                enabled: widget.enabled,
                onPressed: () => _sendMouse(
                  action: 'double_click',
                  arguments: const <String, dynamic>{'button': 'left'},
                ),
              ),
              RemoteButton(
                label: _dragLocked ? 'Release Drag' : 'Drag Lock',
                enabled: widget.enabled,
                onPressed: _toggleDragLock,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
