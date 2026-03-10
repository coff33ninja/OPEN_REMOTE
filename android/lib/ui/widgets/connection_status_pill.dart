import 'package:flutter/material.dart';

import '../../core/networking/websocket_client.dart';

class ConnectionStatusPill extends StatelessWidget {
  const ConnectionStatusPill({
    super.key,
    required this.state,
  });

  final RemoteConnectionState state;

  @override
  Widget build(BuildContext context) {
    final label = switch (state) {
      RemoteConnectionState.connected => 'Connected',
      RemoteConnectionState.connecting => 'Connecting',
      RemoteConnectionState.error => 'Offline',
      RemoteConnectionState.disconnected => 'Offline',
    };
    final icon = switch (state) {
      RemoteConnectionState.connected => Icons.wifi,
      RemoteConnectionState.connecting => Icons.sync,
      RemoteConnectionState.error => Icons.wifi_off,
      RemoteConnectionState.disconnected => Icons.wifi_off,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
