import 'package:flutter/material.dart';

import '../../core/models/device.dart';
import 'qr_scanner_screen.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.favoriteDeviceIds,
    required this.recentDeviceIds,
    required this.statusMessage,
    required this.onConnect,
    required this.onWake,
    required this.onPairUriSubmit,
    required this.onToggleFavoriteDevice,
    required this.onDeleteDevice,
    required this.onRefreshDevices,
  });

  final List<Device> devices;
  final Device? selectedDevice;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final String statusMessage;
  final Future<void> Function(Device device) onConnect;
  final Future<void> Function(Device device) onWake;
  final Future<void> Function(String pairUri) onPairUriSubmit;
  final Future<void> Function(Device device) onToggleFavoriteDevice;
  final Future<void> Function(Device device) onDeleteDevice;
  final Future<void> Function() onRefreshDevices;

  @override
  State<DeviceManagerScreen> createState() => _DeviceManagerScreenState();
}

class _DeviceManagerScreenState extends State<DeviceManagerScreen> {
  final TextEditingController _pairUriController = TextEditingController();

  @override
  void dispose() {
    _pairUriController.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final scannedUri = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (BuildContext context) => const PairQrScannerScreen(),
      ),
    );
    if (scannedUri != null && scannedUri.isNotEmpty) {
      _pairUriController.text = scannedUri;
      await widget.onPairUriSubmit(scannedUri);
    }
  }

  Future<void> _confirmDelete(Device device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Forget ${device.name}?'),
          content: const Text(
            'This removes the saved device from Android. If the desktop is still discoverable on the current network, it can appear again after a refresh.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Forget'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await widget.onDeleteDevice(device);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  'Device manager',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(widget.statusMessage),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _SummaryPill(
                      icon: Icons.devices_outlined,
                      label: '${widget.devices.length} devices',
                    ),
                    _SummaryPill(
                      icon: Icons.star_outline,
                      label: '${widget.favoriteDeviceIds.length} favorites',
                    ),
                    _SummaryPill(
                      icon: Icons.history,
                      label: '${widget.recentDeviceIds.length} recent',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: widget.onRefreshDevices,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh discovery'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _scanQrCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan and pair'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Add a device',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Paste a pairing URI from the desktop to register a new device, including VPN routes such as Tailscale when they are advertised.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _pairUriController,
                  decoration: const InputDecoration(
                    labelText: 'openremote://pair?...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      widget.onPairUriSubmit(_pairUriController.text),
                  icon: const Icon(Icons.link),
                  label: const Text('Pair via URI'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.devices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No devices are currently stored. Pair a desktop from the card above or refresh discovery.',
              ),
            ),
          )
        else
          ...widget.devices.map(
            (Device device) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ManagedDeviceCard(
                device: device,
                selectedDevice: widget.selectedDevice,
                favoriteDeviceIds: widget.favoriteDeviceIds,
                recentDeviceIds: widget.recentDeviceIds,
                onConnect: widget.onConnect,
                onWake: widget.onWake,
                onToggleFavoriteDevice: widget.onToggleFavoriteDevice,
                onDeleteDevice: _confirmDelete,
              ),
            ),
          ),
      ],
    );
  }
}

class _ManagedDeviceCard extends StatelessWidget {
  const _ManagedDeviceCard({
    required this.device,
    required this.selectedDevice,
    required this.favoriteDeviceIds,
    required this.recentDeviceIds,
    required this.onConnect,
    required this.onWake,
    required this.onToggleFavoriteDevice,
    required this.onDeleteDevice,
  });

  final Device device;
  final Device? selectedDevice;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final Future<void> Function(Device device) onConnect;
  final Future<void> Function(Device device) onWake;
  final Future<void> Function(Device device) onToggleFavoriteDevice;
  final Future<void> Function(Device device) onDeleteDevice;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (selectedDevice?.id == device.id) const _DeviceBadge(label: 'Current'),
      if (favoriteDeviceIds.contains(device.id))
        const _DeviceBadge(label: 'Favorite'),
      if (recentDeviceIds.contains(device.id))
        const _DeviceBadge(label: 'Recent'),
      if ((device.accessToken ?? '').isNotEmpty)
        const _DeviceBadge(label: 'Paired'),
      if (device.canWake) const _DeviceBadge(label: 'Wake-ready'),
      if ((device.accessToken ?? '').isEmpty)
        const _DeviceBadge(label: 'Discovery only'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text('${device.host}:${device.port}'),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onToggleFavoriteDevice(device),
                  icon: Icon(
                    favoriteDeviceIds.contains(device.id)
                        ? Icons.star
                        : Icons.star_border,
                  ),
                ),
                IconButton(
                  onPressed: () => onDeleteDevice(device),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: badges,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => onConnect(device),
                  icon: const Icon(Icons.link),
                  label: Text(
                    selectedDevice?.id == device.id ? 'Reconnect' : 'Connect',
                  ),
                ),
                if (device.canWake)
                  OutlinedButton.icon(
                    onPressed: () => onWake(device),
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Wake'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF0ECE4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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

class _DeviceBadge extends StatelessWidget {
  const _DeviceBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2E9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
