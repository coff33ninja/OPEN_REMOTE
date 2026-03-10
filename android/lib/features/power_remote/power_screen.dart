import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../core/models/device.dart';

class PowerScreen extends StatelessWidget {
  const PowerScreen({
    super.key,
    required this.device,
    required this.isConnected,
    required this.onSend,
  });

  final Device? device;
  final bool isConnected;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    final selectedDevice = device;
    if (selectedDevice == null) {
      return const Center(
        child: Text('Select a device to manage power actions.'),
      );
    }

    final primaryRoute = selectedDevice.currentRoute ??
        selectedDevice.lastSuccessfulRoute ??
        selectedDevice.preferredRoute;
    final canWakeOnRoute = primaryRoute?.canWake ?? selectedDevice.canWake;
    final hasWakeRoute = selectedDevice.hasWakeRoute;
    final isLikelyLocal = primaryRoute?.isLikelyLocal ?? false;
    final routeLabel =
        primaryRoute == null ? 'Unknown route' : primaryRoute.kindLabel;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  selectedDevice.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text('${selectedDevice.host}:${selectedDevice.port}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _StatusPill(
                      label: isConnected ? 'Live' : 'Offline',
                      icon: isConnected ? Icons.wifi : Icons.wifi_off,
                    ),
                    _StatusPill(
                      label: routeLabel,
                      icon: Icons.route_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!isConnected)
          _OfflinePowerCard(
            device: selectedDevice,
            hasWakeRoute: hasWakeRoute,
            canWakeOnRoute: canWakeOnRoute,
            isLikelyLocal: isLikelyLocal,
            routeLabel: routeLabel,
            onSend: onSend,
          )
        else
          _OnlinePowerCard(
            device: selectedDevice,
            onSend: onSend,
          ),
      ],
    );
  }
}

class _OnlinePowerCard extends StatelessWidget {
  const _OnlinePowerCard({
    required this.device,
    required this.onSend,
  });

  final Device device;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Power controls',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The agent is reachable. Use these controls to shut down or restart the device.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _PowerButton(
                  icon: Icons.restart_alt,
                  label: 'Restart',
                  onPressed: () => onSend(_powerCommand('power_restart')),
                ),
                _PowerButton(
                  icon: Icons.power_settings_new,
                  label: 'Shutdown',
                  tone: _PowerButtonTone.danger,
                  onPressed: () => onSend(_powerCommand('power_shutdown')),
                ),
                _PowerButton(
                  icon: Icons.bedtime_outlined,
                  label: 'Sleep',
                  tone: _PowerButtonTone.secondary,
                  onPressed: () => onSend(_powerCommand('power_sleep')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflinePowerCard extends StatelessWidget {
  const _OfflinePowerCard({
    required this.device,
    required this.hasWakeRoute,
    required this.canWakeOnRoute,
    required this.isLikelyLocal,
    required this.routeLabel,
    required this.onSend,
  });

  final Device device;
  final bool hasWakeRoute;
  final bool canWakeOnRoute;
  final bool isLikelyLocal;
  final String routeLabel;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  Widget build(BuildContext context) {
    final warningText = hasWakeRoute && !canWakeOnRoute
        ? 'Wake-on-LAN is available only on a local route. Current route: $routeLabel.'
        : null;
    final routeMismatchText = !isLikelyLocal
        ? 'This device appears to be on a non-local route. Pick a LAN route in Device Manager or re-pair on the same network.'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Wake device',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'The agent is offline. Wake-on-LAN is the only action available until it comes back online.',
            ),
            if (warningText != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                warningText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A3B12),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            if (routeMismatchText != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                routeMismatchText,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A3B12),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            if (!hasWakeRoute) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'No wake route is configured for this device. Pair it on the same LAN to capture a wake target.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A3B12),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _PowerButton(
                  icon: Icons.power_settings_new,
                  label: 'Wake',
                  onPressed: hasWakeRoute
                      ? () => onSend(_powerCommand('power_wake'))
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerButton extends StatelessWidget {
  const _PowerButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.tone = _PowerButtonTone.primary,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final _PowerButtonTone tone;

  @override
  Widget build(BuildContext context) {
    final style = switch (tone) {
      _PowerButtonTone.primary => FilledButton.styleFrom(),
      _PowerButtonTone.secondary => FilledButton.styleFrom(
          backgroundColor: const Color(0xFFF9E6CA),
          foregroundColor: const Color(0xFF5B2A0A),
        ),
      _PowerButtonTone.danger => FilledButton.styleFrom(
          backgroundColor: const Color(0xFF9A3412),
          foregroundColor: Colors.white,
        ),
    };

    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0EC),
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

CommandEnvelope _powerCommand(String name) {
  return CommandEnvelope(
    type: 'power',
    name: name,
    remoteId: 'power-controls',
  );
}

enum _PowerButtonTone {
  primary,
  secondary,
  danger,
}
