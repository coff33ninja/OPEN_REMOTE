import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../ui/widgets/remote_button.dart';

class MediaScreen extends StatefulWidget {
  const MediaScreen({
    super.key,
    required this.enabled,
    required this.onSend,
  });

  final bool enabled;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen> {
  double _volume = 50;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            RemoteButton(
              label: 'Play / Pause',
              enabled: widget.enabled,
              onPressed: () => widget.onSend(
                const CommandEnvelope(type: 'media', action: 'toggle'),
              ),
            ),
            RemoteButton(
              label: 'Previous',
              enabled: widget.enabled,
              onPressed: () => widget.onSend(
                const CommandEnvelope(type: 'media', action: 'previous'),
              ),
            ),
            RemoteButton(
              label: 'Next',
              enabled: widget.enabled,
              onPressed: () => widget.onSend(
                const CommandEnvelope(type: 'media', action: 'next'),
              ),
            ),
            RemoteButton(
              label: 'Stop',
              enabled: widget.enabled,
              onPressed: () => widget.onSend(
                const CommandEnvelope(type: 'media', action: 'stop'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Volume ${_volume.round()}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Slider(
          value: _volume,
          min: 0,
          max: 100,
          divisions: 20,
          onChanged: widget.enabled
              ? (double value) {
                  setState(() {
                    _volume = value;
                  });
                }
              : null,
          onChangeEnd: widget.enabled
              ? (double value) {
                  widget.onSend(
                    CommandEnvelope(
                      type: 'volume',
                      action: 'set',
                      arguments: <String, dynamic>{'value': value.round()},
                    ),
                  );
                }
              : null,
        ),
      ],
    );
  }
}
