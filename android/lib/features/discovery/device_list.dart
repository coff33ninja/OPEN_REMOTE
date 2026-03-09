import 'package:flutter/material.dart';

import '../../core/models/device.dart';
import '../../ui/widgets/network_route_icons.dart';
import 'qr_scanner_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.favoriteDeviceIds,
    required this.recentDeviceIds,
    required this.statusMessage,
    required this.isConnected,
    required this.pendingSharedCount,
    required this.onConnect,
    required this.onWake,
    required this.onPairUriSubmit,
    required this.onToggleFavoriteDevice,
    required this.onRefreshDevices,
    required this.onOpenDeviceManager,
  });

  final List<Device> devices;
  final Device? selectedDevice;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final String statusMessage;
  final bool isConnected;
  final int pendingSharedCount;
  final Future<void> Function(Device device) onConnect;
  final Future<void> Function(Device device) onWake;
  final Future<void> Function(String pairUri) onPairUriSubmit;
  final Future<void> Function(Device device) onToggleFavoriteDevice;
  final Future<void> Function() onRefreshDevices;
  final VoidCallback onOpenDeviceManager;

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

  @override
  Widget build(BuildContext context) {
    final quickDevices = widget.devices.take(3).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _DashboardHero(
          selectedDevice: widget.selectedDevice,
          statusMessage: widget.statusMessage,
          deviceCount: widget.devices.length,
          pendingSharedCount: widget.pendingSharedCount,
          isConnected: widget.isConnected,
          onManageDevices: widget.onOpenDeviceManager,
          onRefreshDevices: widget.onRefreshDevices,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pair a desktop',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use the QR code or pairing URI from the desktop app. This is also where VPN and LAN routes are validated after a scan.',
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
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: () =>
                          widget.onPairUriSubmit(_pairUriController.text),
                      icon: const Icon(Icons.link),
                      label: const Text('Pair via URI'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _scanQrCode,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (widget.selectedDevice != null)
          _SelectedDeviceCard(
            device: widget.selectedDevice!,
            favoriteDeviceIds: widget.favoriteDeviceIds,
            recentDeviceIds: widget.recentDeviceIds,
            isConnected: widget.isConnected,
            onConnect: widget.onConnect,
            onWake: widget.onWake,
            onToggleFavoriteDevice: widget.onToggleFavoriteDevice,
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'No active device',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Open the device manager to curate paired machines, clean out stale entries, or reconnect to a recent desktop.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: widget.onOpenDeviceManager,
                    icon: const Icon(Icons.devices_outlined),
                    label: const Text('Open device manager'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Quick picks',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Favorites and recent desktops stay near the top for faster reconnects.',
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: widget.onOpenDeviceManager,
              child: const Text('Manage all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (quickDevices.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No devices have been discovered yet. Pair a desktop manually or refresh discovery.',
              ),
            ),
          )
        else
          ...quickDevices.map(
            (Device device) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _QuickDeviceCard(
                device: device,
                selectedDevice: widget.selectedDevice,
                favoriteDeviceIds: widget.favoriteDeviceIds,
                recentDeviceIds: widget.recentDeviceIds,
                onConnect: widget.onConnect,
                onWake: widget.onWake,
                onToggleFavoriteDevice: widget.onToggleFavoriteDevice,
              ),
            ),
          ),
      ],
    );
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.selectedDevice,
    required this.statusMessage,
    required this.deviceCount,
    required this.pendingSharedCount,
    required this.isConnected,
    required this.onManageDevices,
    required this.onRefreshDevices,
  });

  final Device? selectedDevice;
  final String statusMessage;
  final int deviceCount;
  final int pendingSharedCount;
  final bool isConnected;
  final VoidCallback onManageDevices;
  final Future<void> Function() onRefreshDevices;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF8A3B12),
              Color(0xFFB45309),
              Color(0xFFE29A19),
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Control deck',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              selectedDevice?.name ?? 'No device selected',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              statusMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFFDF2E6),
                  ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _HeroStatPill(
                  icon: isConnected ? Icons.wifi : Icons.wifi_tethering_off,
                  label: isConnected ? 'Live session' : 'Standby',
                ),
                _HeroStatPill(
                  icon: Icons.devices_outlined,
                  label: '$deviceCount devices',
                ),
                _HeroStatPill(
                  icon: Icons.upload_file_outlined,
                  label: pendingSharedCount == 0
                      ? 'No queued shares'
                      : '$pendingSharedCount queued shares',
                ),
              ],
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: onManageDevices,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF9E6CA),
                    foregroundColor: const Color(0xFF5B2A0A),
                  ),
                  icon: const Icon(Icons.devices_outlined),
                  label: const Text('Manage devices'),
                ),
                OutlinedButton.icon(
                  onPressed: onRefreshDevices,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFF9E6CA)),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh discovery'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatPill extends StatelessWidget {
  const _HeroStatPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0x2EF8E7D0),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDeviceCard extends StatelessWidget {
  const _SelectedDeviceCard({
    required this.device,
    required this.favoriteDeviceIds,
    required this.recentDeviceIds,
    required this.isConnected,
    required this.onConnect,
    required this.onWake,
    required this.onToggleFavoriteDevice,
  });

  final Device device;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final bool isConnected;
  final Future<void> Function(Device device) onConnect;
  final Future<void> Function(Device device) onWake;
  final Future<void> Function(Device device) onToggleFavoriteDevice;

  @override
  Widget build(BuildContext context) {
    final primaryRoute = device.currentRoute ??
        device.lastSuccessfulRoute ??
        device.preferredRoute;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        'Active device',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('${device.host}:${device.port}'),
                      if (primaryRoute != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          '${primaryRoute.kindLabel} route • ${primaryRoute.displayName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _deviceBadges(
                device: device,
                favoriteDeviceIds: favoriteDeviceIds,
                recentDeviceIds: recentDeviceIds,
                selectedDevice: device,
                isConnected: isConnected,
              ),
            ),
            if (primaryRoute != null &&
                !primaryRoute.canWake &&
                device.hasWakeRoute)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Wake-on-LAN is available on a local route, but not on the active ${primaryRoute.kindLabel.toLowerCase()} route.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A3B12),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            if (device.hasRouteIssue)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Last route failure: ${device.lastFailureMessage ?? device.lastFailedRouteHost ?? 'unknown error'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A3B12),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                FilledButton.icon(
                  onPressed: () => onConnect(device),
                  icon: Icon(
                    isConnected ? Icons.sync : Icons.link,
                  ),
                  label: Text(isConnected ? 'Reconnect' : 'Connect'),
                ),
                if (device.hasWakeRoute)
                  OutlinedButton.icon(
                    onPressed: () => onWake(device),
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Wake device'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDeviceCard extends StatelessWidget {
  const _QuickDeviceCard({
    required this.device,
    required this.selectedDevice,
    required this.favoriteDeviceIds,
    required this.recentDeviceIds,
    required this.onConnect,
    required this.onWake,
    required this.onToggleFavoriteDevice,
  });

  final Device device;
  final Device? selectedDevice;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final Future<void> Function(Device device) onConnect;
  final Future<void> Function(Device device) onWake;
  final Future<void> Function(Device device) onToggleFavoriteDevice;

  @override
  Widget build(BuildContext context) {
    final primaryRoute = device.currentRoute ??
        device.lastSuccessfulRoute ??
        device.preferredRoute;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                        device.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('${device.host}:${device.port}'),
                      if (primaryRoute != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          '${primaryRoute.kindLabel} route • ${primaryRoute.displayName}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _deviceBadges(
                device: device,
                favoriteDeviceIds: favoriteDeviceIds,
                recentDeviceIds: recentDeviceIds,
                selectedDevice: selectedDevice,
              ),
            ),
            if (primaryRoute != null &&
                !primaryRoute.canWake &&
                device.hasWakeRoute)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Wake works only on a local route for this device.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A3B12),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            if (device.hasRouteIssue)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Last route failure: ${device.lastFailureMessage ?? device.lastFailedRouteHost ?? 'unknown error'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF8A3B12),
                        fontWeight: FontWeight.w600,
                      ),
                ),
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
                if (device.hasWakeRoute)
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

List<Widget> _deviceBadges({
  required Device device,
  required Set<String> favoriteDeviceIds,
  required List<String> recentDeviceIds,
  required Device? selectedDevice,
  bool isConnected = false,
}) {
  final badges = <Widget>[
    if ((device.currentRoute ??
            device.lastSuccessfulRoute ??
            device.preferredRoute) !=
        null)
      _DeviceBadgeChip(
        label: (device.currentRoute ??
                device.lastSuccessfulRoute ??
                device.preferredRoute)!
            .kindLabel,
        backgroundColor: const Color(0xFFE4ECF8),
        icon: networkRouteIcon(
          (device.currentRoute ??
                  device.lastSuccessfulRoute ??
                  device.preferredRoute)!
              .kind,
          canWake: (device.currentRoute ??
                  device.lastSuccessfulRoute ??
                  device.preferredRoute)!
              .canWake,
          isVirtual: (device.currentRoute ??
                  device.lastSuccessfulRoute ??
                  device.preferredRoute)!
              .isVirtual,
        ),
      ),
    if (selectedDevice?.id == device.id)
      _DeviceBadgeChip(
        label: isConnected ? 'Live' : 'Selected',
        backgroundColor:
            isConnected ? const Color(0xFFD9F8E6) : const Color(0xFFE8F0FE),
        icon: isConnected ? Icons.wifi : Icons.radio_button_checked,
      ),
    if (favoriteDeviceIds.contains(device.id))
      const _DeviceBadgeChip(
        label: 'Favorite',
        backgroundColor: Color(0xFFFCE7C3),
        icon: Icons.star,
      ),
    if ((device.preferredRouteHost ?? '').trim().isNotEmpty)
      const _DeviceBadgeChip(
        label: 'Preferred route',
        backgroundColor: Color(0xFFEDE2FA),
        icon: Icons.route,
      ),
    if (device.routePolicy != DeviceRoutePolicy.inherit)
      _DeviceBadgeChip(
        label: deviceRoutePolicyLabel(device.routePolicy),
        backgroundColor: const Color(0xFFE7EEF7),
        icon: device.routePolicy == DeviceRoutePolicy.localFirst
            ? Icons.wifi
            : Icons.route,
      ),
    if (recentDeviceIds.contains(device.id))
      const _DeviceBadgeChip(
        label: 'Recent',
        backgroundColor: Color(0xFFE9ECF5),
        icon: Icons.history,
      ),
    if ((device.accessToken ?? '').isNotEmpty)
      const _DeviceBadgeChip(
        label: 'Paired',
        backgroundColor: Color(0xFFE5F4EA),
        icon: Icons.verified_user_outlined,
      ),
    if (device.hasWakeRoute)
      const _DeviceBadgeChip(
        label: 'Wake-ready',
        backgroundColor: Color(0xFFF7E0D6),
        icon: Icons.power_settings_new,
      ),
    if (device.hasRouteIssue)
      const _DeviceBadgeChip(
        label: 'Route issue',
        backgroundColor: Color(0xFFF8D7D7),
        icon: Icons.error_outline,
      ),
  ];

  return badges.isEmpty
      ? const <Widget>[
          _DeviceBadgeChip(
            label: 'Discovered',
            backgroundColor: Color(0xFFF1F0EC),
            icon: Icons.travel_explore,
          ),
        ]
      : badges;
}

class _DeviceBadgeChip extends StatelessWidget {
  const _DeviceBadgeChip({
    required this.label,
    required this.backgroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
