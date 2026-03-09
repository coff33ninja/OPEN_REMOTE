import 'package:flutter/material.dart';

import '../../core/models/device.dart';
import 'qr_scanner_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({
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

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final TextEditingController _pairUriController = TextEditingController();

  @override
  void dispose() {
    _pairUriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        Card(
          child: ListTile(
            title: const Text('Discovery status'),
            subtitle: Text(widget.statusMessage),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text('Pair from the desktop QR or URI'),
                const SizedBox(height: 12),
                TextField(
                  controller: _pairUriController,
                  decoration: const InputDecoration(
                    labelText: 'openremote://pair?...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      widget.onPairUriSubmit(_pairUriController.text),
                  child: const Text('Pair via URI'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final scannedUri = await Navigator.of(context).push<String>(
                      MaterialPageRoute<String>(
                        builder: (BuildContext context) =>
                            const PairQrScannerScreen(),
                      ),
                    );
                    if (scannedUri != null && scannedUri.isNotEmpty) {
                      _pairUriController.text = scannedUri;
                      await widget.onPairUriSubmit(scannedUri);
                    }
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR Code'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Discovered agents come from mDNS. You can also paste an OpenRemote pair URI directly to trust a device and connect immediately.',
        ),
        const SizedBox(height: 16),
        ...widget.devices.map(
          (Device device) {
            final badges = <String>[
              if (widget.favoriteDeviceIds.contains(device.id)) 'Favorite',
              if (widget.recentDeviceIds.contains(device.id)) 'Recent',
              if (device.accessToken != null && device.accessToken!.isNotEmpty)
                'Paired',
            ];

            return Card(
              child: ListTile(
                title: Text(device.name),
                subtitle: Text(
                  '${device.host}:${device.port}'
                  '${badges.isEmpty ? '' : '  •  ${badges.join(' • ')}'}',
                ),
                leading: IconButton(
                  icon: Icon(
                    widget.favoriteDeviceIds.contains(device.id)
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  onPressed: () => widget.onToggleFavoriteDevice(device),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (device.canWake) ...<Widget>[
                      OutlinedButton(
                        onPressed: () => widget.onWake(device),
                        child: const Text('Wake'),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton(
                      onPressed: () => widget.onConnect(device),
                      child: Text(
                        widget.selectedDevice?.id == device.id
                            ? 'Selected'
                            : 'Connect',
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
