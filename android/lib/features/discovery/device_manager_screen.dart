import 'package:flutter/material.dart';

import '../../core/models/device.dart';
import '../../ui/widgets/network_route_icons.dart';
import 'qr_scanner_screen.dart';

class DeviceManagerScreen extends StatefulWidget {
  const DeviceManagerScreen({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.favoriteDeviceIds,
    required this.recentDeviceIds,
    required this.statusMessage,
    required this.preferLocalRoutes,
    required this.onConnect,
    required this.onWake,
    required this.onPairUriSubmit,
    required this.onToggleFavoriteDevice,
    required this.onDeleteDevice,
    required this.onRefreshDevices,
    required this.onSetPreferredRoute,
    required this.onSetRoutePolicy,
    required this.onPreferLocalRoutesChanged,
  });

  final List<Device> devices;
  final Device? selectedDevice;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final String statusMessage;
  final bool preferLocalRoutes;
  final Future<void> Function(Device device) onConnect;
  final Future<void> Function(Device device) onWake;
  final Future<void> Function(String pairUri) onPairUriSubmit;
  final Future<void> Function(Device device) onToggleFavoriteDevice;
  final Future<void> Function(Device device) onDeleteDevice;
  final Future<void> Function() onRefreshDevices;
  final Future<void> Function(Device device, NetworkRoute route)
      onSetPreferredRoute;
  final Future<void> Function(Device device, String policy) onSetRoutePolicy;
  final Future<void> Function(bool value) onPreferLocalRoutesChanged;

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

  Future<void> _showDeviceDetails(Device device) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: _DeviceDetailsSheet(
              device: device,
              onSetPreferredRoute: (NetworkRoute route) async {
                Navigator.of(context).pop();
                await widget.onSetPreferredRoute(device, route);
              },
              onSetRoutePolicy: (String policy) async {
                Navigator.of(context).pop();
                await widget.onSetRoutePolicy(device, policy);
              },
            ),
          ),
        );
      },
    );
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: widget.preferLocalRoutes,
                  title: const Text('Default to local LAN when available'),
                  subtitle: const Text(
                    'Devices can override this in their details. When enabled, Wi-Fi and Ethernet routes are tried before VPN and remote-only paths.',
                  ),
                  onChanged: widget.onPreferLocalRoutesChanged,
                ),
                const SizedBox(height: 8),
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
                onShowDetails: _showDeviceDetails,
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
    required this.onShowDetails,
  });

  final Device device;
  final Device? selectedDevice;
  final Set<String> favoriteDeviceIds;
  final List<String> recentDeviceIds;
  final Future<void> Function(Device device) onConnect;
  final Future<void> Function(Device device) onWake;
  final Future<void> Function(Device device) onToggleFavoriteDevice;
  final Future<void> Function(Device device) onDeleteDevice;
  final Future<void> Function(Device device) onShowDetails;

  @override
  Widget build(BuildContext context) {
    final primaryRoute = device.currentRoute ??
        device.lastSuccessfulRoute ??
        device.preferredRoute;
    final badges = <Widget>[
      if (selectedDevice?.id == device.id)
        const _DeviceBadge(label: 'Current', icon: Icons.radio_button_checked),
      if (favoriteDeviceIds.contains(device.id))
        const _DeviceBadge(label: 'Favorite', icon: Icons.star),
      if (recentDeviceIds.contains(device.id))
        const _DeviceBadge(label: 'Recent', icon: Icons.history),
      if ((device.accessToken ?? '').isNotEmpty)
        const _DeviceBadge(label: 'Paired', icon: Icons.verified_user_outlined),
      if (primaryRoute != null)
        _DeviceBadge(
          label: primaryRoute.kindLabel,
          icon: networkRouteIcon(
            primaryRoute.kind,
            canWake: primaryRoute.canWake,
            isVirtual: primaryRoute.isVirtual,
          ),
        ),
      if ((device.preferredRouteHost ?? '').trim().isNotEmpty)
        const _DeviceBadge(label: 'Preferred route', icon: Icons.route),
      if (device.routePolicy != DeviceRoutePolicy.inherit)
        _DeviceBadge(
          label: deviceRoutePolicyLabel(device.routePolicy),
          icon: device.routePolicy == DeviceRoutePolicy.localFirst
              ? Icons.wifi
              : Icons.route,
        ),
      if (device.hasWakeRoute)
        const _DeviceBadge(label: 'Wake-ready', icon: Icons.power_settings_new),
      if (device.hasRouteIssue)
        const _DeviceBadge(label: 'Route issue', icon: Icons.error_outline),
      if ((device.accessToken ?? '').isEmpty)
        const _DeviceBadge(label: 'Discovery only', icon: Icons.travel_explore),
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
            if (primaryRoute != null &&
                !primaryRoute.canWake &&
                device.hasWakeRoute)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Wake-on-LAN is available only on a local route for this device.',
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
                OutlinedButton.icon(
                  onPressed: () => onShowDetails(device),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceDetailsSheet extends StatelessWidget {
  const _DeviceDetailsSheet({
    required this.device,
    required this.onSetPreferredRoute,
    required this.onSetRoutePolicy,
  });

  final Device device;
  final Future<void> Function(NetworkRoute route) onSetPreferredRoute;
  final Future<void> Function(String policy) onSetRoutePolicy;

  @override
  Widget build(BuildContext context) {
    final routes = device.networkRoutes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          device.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text('${device.host}:${device.port}'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            _SummaryPill(
              icon: Icons.visibility_outlined,
              label: _formatTimestampLabel(
                prefix: 'Last seen',
                value: device.lastSeenAt,
              ),
            ),
            _SummaryPill(
              icon: Icons.link,
              label: _formatTimestampLabel(
                prefix: 'Last connected',
                value: device.lastConnectedAt,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if ((device.lastSuccessfulRouteHost ?? '').trim().isNotEmpty)
          Text(
            'Last successful route: ${device.lastSuccessfulRoute?.displayName ?? device.lastSuccessfulRouteHost}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        if ((device.lastFailedRouteHost ?? '').trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Last failed route: ${device.lastFailedRouteHost}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF8A3B12),
                  fontWeight: FontWeight.w600,
                ),
          ),
          if ((device.lastFailureMessage ?? '').trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                device.lastFailureMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF8A3B12),
                    ),
              ),
            ),
        ],
        const SizedBox(height: 16),
        Text(
          'Route policy',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const <ButtonSegment<String>>[
            ButtonSegment<String>(
              value: DeviceRoutePolicy.inherit,
              label: Text('Default'),
              icon: Icon(Icons.auto_awesome),
            ),
            ButtonSegment<String>(
              value: DeviceRoutePolicy.localFirst,
              label: Text('Local'),
              icon: Icon(Icons.wifi),
            ),
            ButtonSegment<String>(
              value: DeviceRoutePolicy.rememberedFirst,
              label: Text('Remembered'),
              icon: Icon(Icons.route),
            ),
          ],
          selected: <String>{device.routePolicy},
          onSelectionChanged: (Set<String> selection) {
            if (selection.isEmpty) {
              return;
            }
            onSetRoutePolicy(selection.first);
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Default uses the global app preference. Local favors Wi-Fi and Ethernet. Remembered favors the preferred or last-working route first.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        Text(
          'Advertised routes',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (routes.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
                'No route metadata has been reported for this device yet.'),
          )
        else
          ...routes.map(
            (NetworkRoute route) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                networkRouteIcon(
                  route.kind,
                  canWake: route.canWake,
                  isVirtual: route.isVirtual,
                ),
              ),
              title: Text(route.displayName),
              subtitle: Text(
                [
                  route.kindLabel,
                  route.host,
                  if (route.description.trim().isNotEmpty) route.description,
                  if (route.canWake)
                    'Wake-on-LAN available'
                  else
                    'No Wake-on-LAN',
                ].join(' • '),
              ),
              trailing: route.host.trim().toLowerCase() ==
                      (device.preferredRouteHost ?? '').trim().toLowerCase()
                  ? const Icon(Icons.check_circle, color: Color(0xFF0F766E))
                  : TextButton(
                      onPressed: () => onSetPreferredRoute(route),
                      child: const Text('Prefer'),
                    ),
            ),
          ),
      ],
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
    this.icon,
  });

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F2E9),
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

String _formatTimestampLabel({
  required String prefix,
  required DateTime? value,
}) {
  if (value == null) {
    return '$prefix unknown';
  }

  final delta = DateTime.now().toUtc().difference(value.toUtc());
  if (delta.inMinutes < 1) {
    return '$prefix just now';
  }
  if (delta.inHours < 1) {
    return '$prefix ${delta.inMinutes}m ago';
  }
  if (delta.inDays < 1) {
    return '$prefix ${delta.inHours}h ago';
  }
  return '$prefix ${delta.inDays}d ago';
}
