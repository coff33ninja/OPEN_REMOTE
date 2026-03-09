import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../ui/widgets/remote_button.dart';

class KeyboardScreen extends StatefulWidget {
  const KeyboardScreen({
    super.key,
    required this.enabled,
    required this.onSend,
  });

  final bool enabled;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    await widget.onSend(
      CommandEnvelope(
        type: 'keyboard',
        action: 'type',
        arguments: <String, dynamic>{'text': text},
      ),
    );
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Type text for the remote computer',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 5,
          ),
          const SizedBox(height: 16),
          RemoteButton(
            label: 'Send Text',
            enabled: widget.enabled,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
