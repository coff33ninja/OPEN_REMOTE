import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../ui/widgets/remote_button.dart';

class MouseScreen extends StatelessWidget {
  const MouseScreen({
    super.key,
    required this.enabled,
    required this.onSend,
  });

  final bool enabled;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            enabled
                ? 'Drag to send mouse movement.'
                : 'Connect to an agent first.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GestureDetector(
              onPanUpdate: enabled
                  ? (DragUpdateDetails details) {
                      onSend(
                        CommandEnvelope(
                          type: 'mouse',
                          action: 'move',
                          remoteId: 'mouse-touchpad',
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
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Text(
                    'Touchpad',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: RemoteButton(
                  label: 'Left Click',
                  enabled: enabled,
                  onPressed: () => onSend(
                    const CommandEnvelope(
                      type: 'mouse',
                      action: 'click',
                      arguments: <String, dynamic>{'button': 'left'},
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RemoteButton(
                  label: 'Right Click',
                  enabled: enabled,
                  onPressed: () => onSend(
                    const CommandEnvelope(
                      type: 'mouse',
                      action: 'click',
                      arguments: <String, dynamic>{'button': 'right'},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
