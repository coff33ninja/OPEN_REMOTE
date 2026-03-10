import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'core/models/command.dart';
import 'core/models/device.dart';
import 'core/models/pairing.dart';
import 'core/models/remote_layout.dart';
import 'core/networking/api_client.dart';
import 'core/networking/device_connection_resolver.dart';
import 'core/networking/discovery.dart';
import 'core/networking/github_updates_service.dart';
import 'core/networking/pairing_host_resolver.dart';
import 'core/networking/wake_on_lan_client.dart';
import 'core/networking/websocket_client.dart';
import 'core/persistence/app_state_store.dart';
import 'features/custom_remotes/remote_loader.dart';
import 'features/custom_remotes/remote_renderer.dart';
import 'features/discovery/device_manager_screen.dart';
import 'features/discovery/device_list.dart';
import 'features/file_transfer/file_transfer_screen.dart';
import 'features/file_explorer/file_explorer_screen.dart';
import 'features/keyboard_remote/keyboard_screen.dart';
import 'features/media_remote/media_screen.dart';
import 'features/mouse_remote/mouse_screen.dart';
import 'features/power_remote/power_screen.dart';
import 'features/remote_designer/remote_designer_screen.dart';
import 'features/services/services_screen.dart';
import 'features/system_info/system_info_screen.dart';
import 'features/task_manager/task_manager_screen.dart';
import 'features/updates/updates_screen.dart';
import 'ui/themes/app_theme.dart';
import 'ui/widgets/connection_status_pill.dart';
import 'ui/widgets/network_route_icons.dart';

void main() {
  runApp(const OpenRemoteApp());
}

enum _AppSection {
  dashboard('Dashboard', Icons.space_dashboard_outlined),
  devices('Devices', Icons.devices_outlined),
  mouse('Mouse', Icons.mouse_outlined),
  keyboard('Keyboard', Icons.keyboard_outlined),
  media('Media', Icons.perm_media_outlined),
  power('Power', Icons.power_settings_new),
  explorer('Explorer', Icons.folder_open_outlined),
  tasks('Tasks', Icons.checklist_outlined),
  services('Services', Icons.miscellaneous_services_outlined),
  system('System', Icons.insights_outlined),
  files('Files', Icons.upload_file_outlined),
  updates('Updates', Icons.system_update_alt_outlined),
  custom('Custom Remotes', Icons.tune_outlined),
  designer('Designer', Icons.draw_outlined);

  const _AppSection(this.title, this.icon);

  final String title;
  final IconData icon;
}

class OpenRemoteApp extends StatelessWidget {
  const OpenRemoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenRemote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const RemoteHomePage(),
    );
  }
}

class RemoteHomePage extends StatefulWidget {
  const RemoteHomePage({super.key});

  @override
  State<RemoteHomePage> createState() => _RemoteHomePageState();
}

class _RemoteHomePageState extends State<RemoteHomePage> {
  final ApiClient _apiClient = const ApiClient();
  final RemoteClient _client = RemoteClient();
  final DiscoveryService _discoveryService = const DiscoveryService();
  final RemoteLoader _remoteLoader = const RemoteLoader();
  final AppStateStore _appStateStore = const AppStateStore();
  final WakeOnLanClient _wakeOnLanClient = const WakeOnLanClient();
  final GitHubUpdatesService _updatesService = GitHubUpdatesService();
  int _connectAttempt = 0;
  late final VoidCallback _connectionListener;
  Timer? _reconnectTimer;
  DateTime? _lastReconnectAttempt;
  Object? _lastConnectionError;
  RemoteConnectionState _lastConnectionState =
      RemoteConnectionState.disconnected;
  static const Duration _reconnectInterval = Duration(seconds: 20);

  List<Device> _devices = const <Device>[];
  List<RemoteLayout> _remotes = const <RemoteLayout>[];
  List<RemoteLayout> _bundledRemotes = const <RemoteLayout>[];
  List<RemoteLayout> _cachedRemoteLayouts = const <RemoteLayout>[];
  List<RemoteLayout> _designedRemoteLayouts = const <RemoteLayout>[];
  Set<String> _favoriteDeviceIds = <String>{};
  List<String> _recentDeviceIds = const <String>[];
  Set<String> _favoriteRemoteIds = <String>{};
  List<SharedMediaFile> _pendingSharedFiles = const <SharedMediaFile>[];
  Device? _selectedDevice;
  StreamSubscription<List<SharedMediaFile>>? _shareIntentSub;
  bool _loading = true;
  bool _uploadingSharedFiles = false;
  bool _preferLocalRoutes = true;
  bool _selectionLocked = false;
  String _status = 'Ready';
  _AppSection _currentSection = _AppSection.dashboard;

  @override
  void initState() {
    super.initState();
    _connectionListener = () {
      if (!mounted) {
        return;
      }
      final state = _client.connectionState.value;
      if (state == RemoteConnectionState.error) {
        final error = _client.lastError;
        if (error != null && error != _lastConnectionError) {
          _lastConnectionError = error;
          unawaited(
            _reportClientError(
              error,
              screen: 'websocket',
              action: 'connection',
            ),
          );
        }
      }
      if (state != _lastConnectionState &&
          (state == RemoteConnectionState.disconnected ||
              state == RemoteConnectionState.error)) {
        _attemptReconnect();
      }
      _lastConnectionState = state;
      setState(() {});
    };
    _client.connectionState.addListener(_connectionListener);
    _attachGlobalErrorHandlers();
    _startReconnectLoop();
    _bootstrap();
  }

  void _startReconnectLoop() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(_reconnectInterval, (_) {
      _attemptReconnect();
    });
  }

  void _attemptReconnect() {
    if (!mounted || _loading) {
      return;
    }

    final connectionState = _client.connectionState.value;
    if (connectionState == RemoteConnectionState.connected ||
        connectionState == RemoteConnectionState.connecting) {
      return;
    }

    final device = _selectedDevice;
    if (device == null ||
        device.accessToken == null ||
        device.accessToken!.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_lastReconnectAttempt != null &&
        now.difference(_lastReconnectAttempt!) < _reconnectInterval) {
      return;
    }

    _lastReconnectAttempt = now;
    unawaited(_connectToDevice(device, announceRestore: false));
  }

  void _attachGlobalErrorHandlers() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      unawaited(
        _reportClientError(
          details.exception,
          stack: details.stack,
          screen: 'flutter',
          action: 'uncaught',
        ),
      );
    };

    WidgetsBinding.instance.platformDispatcher.onError =
        (Object error, StackTrace stack) {
      unawaited(
        _reportClientError(
          error,
          stack: stack,
          screen: 'platform',
          action: 'uncaught',
        ),
      );
      return true;
    };
  }

  Future<void> _bootstrap() async {
    final persisted = await _appStateStore.load();
    final devices = await _discoveryService.discover();
    final remotes = await _remoteLoader.loadBundledRemotes();
    final mergedDevices = _mergeDevices(
      persisted.pairedDevices,
      devices,
    );
    final mergedRemotes = _mergeRemoteLayouts(
      remotes,
      persisted.cachedRemoteLayouts,
      persisted.designedRemoteLayouts,
    );
    final preferredDevice = persisted.selectedDeviceId == null
        ? null
        : mergedDevices.where((Device device) {
            return device.id == persisted.selectedDeviceId;
          }).firstOrNull;

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = mergedDevices;
      _bundledRemotes = remotes;
      _cachedRemoteLayouts = persisted.cachedRemoteLayouts;
      _designedRemoteLayouts = persisted.designedRemoteLayouts;
      _remotes = mergedRemotes;
      _favoriteDeviceIds = persisted.favoriteDeviceIds;
      _recentDeviceIds = persisted.recentDeviceIds;
      _favoriteRemoteIds = persisted.favoriteRemoteIds;
      _selectedDevice = preferredDevice;
      _preferLocalRoutes = persisted.preferLocalRoutes;
      _selectionLocked = persisted.selectionLocked;
      _loading = false;
    });

    await _initializeShareHandling();

    if (!mounted) {
      return;
    }
    if (preferredDevice != null &&
        preferredDevice.accessToken != null &&
        preferredDevice.accessToken!.isNotEmpty) {
      unawaited(_connectToDevice(preferredDevice, announceRestore: false));
    }
  }

  Future<void> _connectToDevice(
    Device device, {
    bool announceRestore = true,
  }) async {
    if (_selectionLocked &&
        _selectedDevice != null &&
        _selectedDevice!.id != device.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selection locked to ${_selectedDevice!.name}. Unlock to connect.',
          ),
        ),
      );
      return;
    }
    if (device.accessToken == null || device.accessToken!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Pair this device first using an OpenRemote pair URI.')),
      );
      return;
    }

    final attempt = ++_connectAttempt;
    setState(() {
      _status = 'Connecting to ${device.name}';
    });

    Object? lastError;
    String? failedRouteHost;
    try {
      final candidates = deviceConnectionCandidates(
        device,
        defaultPreferLocalRoutes: _preferLocalRoutes,
      );

      for (final NetworkRoute route in candidates) {
        if (attempt != _connectAttempt) {
          return;
        }
        final routeDevice = deviceWithRoute(device, route);
        try {
          final resolvedDevice = await _apiClient.fetchMeta(routeDevice);
          if (attempt != _connectAttempt) {
            return;
          }
          await _client.connect(
            resolvedDevice.websocketUrl,
            accessToken: resolvedDevice.accessToken,
          );
          if (attempt != _connectAttempt) {
            return;
          }
          final remoteCatalog = await _apiClient.fetchRemoteCatalog(
            resolvedDevice,
          );
          if (attempt != _connectAttempt) {
            return;
          }
          if (!mounted) {
            return;
          }
          if (attempt != _connectAttempt) {
            return;
          }

          final connectedDevice = _recordConnectionSuccess(
            resolvedDevice,
            routeHost: route.host,
            rememberRoute: device.preferredRouteHost?.trim().isNotEmpty != true,
          );
          final mergedRemotes = remoteCatalog.isNotEmpty
              ? _mergeRemoteLayouts(
                  _bundledRemotes,
                  remoteCatalog,
                  _designedRemoteLayouts,
                )
              : _mergeRemoteLayouts(
                  _bundledRemotes,
                  _cachedRemoteLayouts,
                  _designedRemoteLayouts,
                );

          setState(() {
            _selectedDevice = connectedDevice;
            _cachedRemoteLayouts =
                remoteCatalog.isNotEmpty ? remoteCatalog : _cachedRemoteLayouts;
            _remotes = mergedRemotes;
            _devices = _replaceOrInsertDevice(connectedDevice);
            _recentDeviceIds = _recordRecentDevice(connectedDevice.id);
            _status = announceRestore
                ? 'Connected to ${connectedDevice.name}'
                : 'Restored ${connectedDevice.name}';
          });

          await _persistState();
          await _flushPendingShares();
          unawaited(_apiClient.flushClientLogs(connectedDevice));
          return;
        } catch (error) {
          if (attempt != _connectAttempt) {
            return;
          }
          lastError = error;
          failedRouteHost = route.host;
        }
      }

      throw lastError ??
          const SocketException('No reachable device route found.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (attempt != _connectAttempt) {
        return;
      }

      setState(() {
        final failedDevice = _recordConnectionFailure(
          device,
          routeHost: failedRouteHost ?? device.host,
          error: error,
        );
        _devices = _replaceOrInsertDevice(failedDevice);
        if (_selectedDevice?.id == device.id) {
          _selectedDevice = failedDevice;
        }
        _status = 'Connection failed';
      });

      unawaited(
        _reportClientError(
          error,
          screen: 'connect',
          action: 'connect',
          context: <String, dynamic>{
            'device_id': device.id,
            'route_host': failedRouteHost ?? device.host,
          },
        ),
      );
      await _persistState();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect: $error')),
      );
    }
  }

  Future<void> _wakeDevice(Device device) async {
    final wakeTarget = device.wakeTarget;
    if (wakeTarget == null || !wakeTarget.isConfigured) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No wake target is configured for ${device.name}.')),
      );
      return;
    }

    setState(() {
      if (!_selectionLocked ||
          _selectedDevice == null ||
          _selectedDevice!.id == device.id) {
        _selectedDevice = device;
      }
      _devices = _replaceOrInsertDevice(device);
      _recentDeviceIds = _recordRecentDevice(device.id);
      _status = 'Sending wake packet to ${device.name}';
    });
    await _persistState();

    try {
      await _wakeOnLanClient.send(wakeTarget);
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Sent wake packet to ${device.name}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Wake failed';
      });

      unawaited(
        _reportClientError(
          error,
          screen: 'power',
          action: 'wake',
          context: <String, dynamic>{'device_id': device.id},
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Wake failed: $error')),
      );
    }
  }

  Future<void> _pairWithUri(String rawUri) async {
    if (rawUri.trim().isEmpty) {
      return;
    }

    setState(() {
      _status = 'Pairing device';
    });

    try {
      final pairing = PairingPayload.fromUri(rawUri);
      final selectedPairing = await _resolvePairingRoute(pairing);
      if (selectedPairing == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _status = 'Pairing cancelled';
        });
        return;
      }

      final pairedDevice = await _completePairing(selectedPairing);

      if (!mounted) {
        return;
      }

      setState(() {
        _devices = _replaceOrInsertDevice(pairedDevice);
        _status = 'Paired with ${pairedDevice.name}';
      });

      await _persistState();
      if (_selectionLocked &&
          _selectedDevice != null &&
          _selectedDevice!.id != pairedDevice.id) {
        setState(() {
          _status = 'Paired with ${pairedDevice.name} (selection locked)';
        });
        await _persistState();
        return;
      }
      await _connectToDevice(pairedDevice);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Pairing failed';
      });

      unawaited(
        _reportClientError(
          error,
          screen: 'pairing',
          action: 'pair',
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pairing failed: $error')),
      );
    }
  }

  Future<PairingPayload?> _resolvePairingRoute(PairingPayload pairing) async {
    final networkOptions = pairing.availableNetworks;
    if (networkOptions.length <= 1 || !mounted) {
      return pairing;
    }

    final choice = await showModalBottomSheet<_PairingRouteChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Choose a network for ${pairing.deviceName}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick a transport explicitly, or let the app decide based on your saved preference for local-first versus remembered routes.',
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_awesome),
                    title: const Text('Auto select best route'),
                    subtitle: const Text(
                      'Try all advertised addresses. Use this if you just want the app to find a reachable path.',
                    ),
                    onTap: () => Navigator.of(context).pop(
                      const _PairingRouteChoice.auto(),
                    ),
                  ),
                  for (final PairingNetworkOption option in networkOptions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        networkRouteIcon(
                          option.kind,
                          canWake: option.canWake,
                          isVirtual: option.isVirtual,
                        ),
                      ),
                      title: Text(option.displayName),
                      subtitle: Text(
                        [
                          option.kindLabel,
                          option.host,
                          if (option.description.trim().isNotEmpty)
                            option.description,
                          if (option.preferred) 'Preferred by agent',
                          option.canWake
                              ? 'Wake-on-LAN available'
                              : 'No Wake-on-LAN',
                        ].join(' • '),
                      ),
                      onTap: () => Navigator.of(context).pop(
                        _PairingRouteChoice.network(option),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (choice == null) {
      return null;
    }
    if (choice.isAuto) {
      return pairing;
    }

    return pairing.selectNetwork(choice.network!);
  }

  Future<Device> _completePairing(PairingPayload pairing) async {
    Object? lastNetworkError;
    final candidates = pairingHostCandidates(
      pairing,
      _devices,
      preferLocalRoutes: _preferLocalRoutes,
    );

    for (final candidate in candidates) {
      try {
        final pairedDevice = await _apiClient.completePairing(
          candidate,
          'OpenRemote Android',
        );
        final now = DateTime.now().toUtc();
        return pairedDevice.copyWith(
          preferredRouteHost: candidate.host,
          lastSeenAt: now,
        );
      } on SocketException catch (error) {
        lastNetworkError = error;
      }
    }

    if (lastNetworkError != null) {
      throw lastNetworkError;
    }

    throw const SocketException('No reachable pairing host was found.');
  }

  Future<void> _toggleFavoriteDevice(Device device) async {
    setState(() {
      if (_favoriteDeviceIds.contains(device.id)) {
        _favoriteDeviceIds = <String>{..._favoriteDeviceIds}..remove(device.id);
      } else {
        _favoriteDeviceIds = <String>{..._favoriteDeviceIds, device.id};
      }
    });
    await _persistState();
  }

  Future<void> _setPreferredRoute(Device device, NetworkRoute route) async {
    final updatedDevice = deviceWithRoute(
      device,
      route,
      markPreferred: true,
    ).copyWith(
      lastSeenAt: DateTime.now().toUtc(),
    );

    setState(() {
      _devices = _replaceOrInsertDevice(updatedDevice);
      if (_selectedDevice?.id == device.id) {
        _selectedDevice = updatedDevice;
      }
      _status = 'Preferred route set to ${route.displayName}';
    });

    await _persistState();
  }

  Future<void> _setRoutePolicy(Device device, String policy) async {
    final updatedDevice = device.copyWith(routePolicy: policy);

    setState(() {
      _devices = _replaceOrInsertDevice(updatedDevice);
      if (_selectedDevice?.id == device.id) {
        _selectedDevice = updatedDevice;
      }
      _status =
          '${updatedDevice.name} now uses ${deviceRoutePolicyLabel(policy).toLowerCase()} routing';
    });

    await _persistState();
  }

  Future<void> _setPreferLocalRoutes(bool value) async {
    setState(() {
      _preferLocalRoutes = value;
      _status = value
          ? 'Local routes will be preferred when available'
          : 'Preferred or last-working routes will be tried first';
    });
    await _persistState();
  }

  Future<void> _setSelectionLocked(bool value) async {
    setState(() {
      _selectionLocked = value;
      _status = value ? 'Selection locked' : 'Selection unlocked';
    });
    await _persistState();
  }

  Future<void> _selectDevice(Device device) async {
    setState(() {
      _selectedDevice = device;
      _status = 'Selected ${device.name}';
    });
    await _persistState();
  }

  Future<void> _openDeviceSelector() async {
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Select device',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectionLocked
                        ? 'Selection is locked. Unlock to auto-switch.'
                        : 'Select a device for all controls. Lock to prevent auto-switch.',
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _selectionLocked,
                    title: const Text('Lock selection'),
                    onChanged: (bool value) async {
                      Navigator.of(context).pop();
                      await _setSelectionLocked(value);
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_devices.isEmpty)
                    const Text('No paired devices yet.')
                  else
                    ..._orderedDevices().map(
                      (Device device) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _selectedDevice?.id == device.id
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(device.name),
                        subtitle: Text('${device.host}:${device.port}'),
                        trailing: FilledButton(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _selectDevice(device);
                          },
                          child: const Text('Select'),
                        ),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await _selectDevice(device);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshDevices() async {
    setState(() {
      _status = 'Refreshing discovery';
    });

    try {
      final discoveredDevices = await _discoveryService.discover();
      final pairedDevices = _devices.where((Device device) {
        final token = device.accessToken;
        return token != null && token.isNotEmpty;
      }).toList();
      final mergedDevices = _mergeDevices(pairedDevices, discoveredDevices);
      final selectedDeviceId = _selectedDevice?.id;
      final refreshedSelection = selectedDeviceId == null
          ? null
          : mergedDevices.where((Device device) {
              return device.id == selectedDeviceId;
            }).firstOrNull;

      if (!mounted) {
        return;
      }

      setState(() {
        _devices = mergedDevices;
        _selectedDevice = refreshedSelection;
        _status = mergedDevices.isEmpty
            ? 'No agents found'
            : 'Found ${mergedDevices.length} agent(s)';
      });

      await _persistState();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Refresh failed';
      });

      unawaited(
        _reportClientError(
          error,
          screen: 'discovery',
          action: 'refresh',
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Discovery refresh failed: $error')),
      );
    }
  }

  Future<void> _deleteDevice(Device device) async {
    final deletingSelectedDevice = _selectedDevice?.id == device.id;
    if (deletingSelectedDevice) {
      await _client.dispose();
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _devices = _devices
          .where((Device existing) => existing.id != device.id)
          .toList();
      _favoriteDeviceIds = <String>{..._favoriteDeviceIds}..remove(device.id);
      _recentDeviceIds = _recentDeviceIds
          .where((String existing) => existing != device.id)
          .toList();
      if (deletingSelectedDevice) {
        _selectedDevice = null;
      }
      _status = 'Removed ${device.name}';
    });

    await _persistState();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deletingSelectedDevice
              ? 'Removed ${device.name} and cleared the active session.'
              : 'Removed ${device.name}.',
        ),
      ),
    );
  }

  Future<void> _toggleFavoriteRemote(RemoteLayout remote) async {
    setState(() {
      if (_favoriteRemoteIds.contains(remote.id)) {
        _favoriteRemoteIds = <String>{..._favoriteRemoteIds}..remove(remote.id);
      } else {
        _favoriteRemoteIds = <String>{..._favoriteRemoteIds, remote.id};
      }
    });
    await _persistState();
  }

  Future<void> _initializeShareHandling() async {
    _shareIntentSub?.cancel();
    _shareIntentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
        (List<SharedMediaFile> value) {
      unawaited(_receiveSharedFiles(value));
    }, onError: (Object error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Share intake failed';
      });
      unawaited(
        _reportClientError(
          error,
          screen: 'sharing',
          action: 'receive',
        ),
      );
    });

    final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
    await _receiveSharedFiles(initialMedia, resetIntent: true);
  }

  Future<void> _receiveSharedFiles(
    List<SharedMediaFile> files, {
    bool resetIntent = false,
  }) async {
    if (files.isEmpty) {
      if (resetIntent) {
        await ReceiveSharingIntent.instance.reset();
      }
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pendingSharedFiles = _mergeSharedFiles(_pendingSharedFiles, files);
      _status =
          'Received ${_pendingSharedFiles.length} shared item(s) for upload';
    });

    if (resetIntent) {
      await ReceiveSharingIntent.instance.reset();
    }

    await _flushPendingShares();
  }

  Future<void> _flushPendingShares() async {
    final device = _selectedDevice;
    if (_uploadingSharedFiles ||
        device == null ||
        device.accessToken == null ||
        device.accessToken!.isEmpty ||
        _pendingSharedFiles.isEmpty) {
      return;
    }

    final queue = List<SharedMediaFile>.from(_pendingSharedFiles);
    final remaining = <SharedMediaFile>[];
    var uploadedCount = 0;

    setState(() {
      _uploadingSharedFiles = true;
      _status = 'Uploading ${queue.length} shared item(s)';
    });

    for (final SharedMediaFile item in queue) {
      try {
        final payload = await _sharedFilePayload(item);
        await _apiClient.uploadFile(
          device,
          fileName: payload.fileName,
          bytes: payload.bytes,
        );
        uploadedCount++;
      } catch (error) {
        remaining.add(item);
        unawaited(
          _reportClientError(
            error,
            screen: 'files',
            action: 'upload_shared',
            context: <String, dynamic>{
              'file_name': item.path.trim().isEmpty
                  ? item.type.value
                  : path.basename(item.path),
              'file_path': item.path,
              'file_type': item.type.value,
            },
          ),
        );
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _pendingSharedFiles = remaining;
      _uploadingSharedFiles = false;
      if (remaining.isEmpty) {
        _status = uploadedCount == 0
            ? _status
            : 'Uploaded $uploadedCount shared item(s)';
      } else {
        _status =
            'Uploaded $uploadedCount item(s), ${remaining.length} still pending';
      }
    });
  }

  Future<_UploadPayload> _sharedFilePayload(SharedMediaFile item) async {
    switch (item.type) {
      case SharedMediaType.text:
        return _UploadPayload(
          fileName: 'shared-text-${DateTime.now().millisecondsSinceEpoch}.txt',
          bytes: item.path.codeUnits,
        );
      case SharedMediaType.url:
        return _UploadPayload(
          fileName: 'shared-link-${DateTime.now().millisecondsSinceEpoch}.url',
          bytes: item.path.codeUnits,
        );
      case SharedMediaType.image:
      case SharedMediaType.video:
      case SharedMediaType.file:
        final file = File(item.path);
        final bytes = await file.readAsBytes();
        return _UploadPayload(
          fileName: path.basename(item.path),
          bytes: bytes,
        );
    }
  }

  Future<void> _persistState() async {
    await _appStateStore.save(
      PersistedAppState(
        pairedDevices: _devices.where((Device device) {
          final token = device.accessToken;
          return token != null && token.isNotEmpty;
        }).toList(),
        favoriteDeviceIds: _favoriteDeviceIds,
        recentDeviceIds: _recentDeviceIds,
        favoriteRemoteIds: _favoriteRemoteIds,
        cachedRemoteLayouts: _cachedRemoteLayouts,
        designedRemoteLayouts: _designedRemoteLayouts,
        selectedDeviceId: _selectedDevice?.id,
        preferLocalRoutes: _preferLocalRoutes,
        selectionLocked: _selectionLocked,
      ),
    );
  }

  List<Device> _mergeDevices(
    List<Device> pairedDevices,
    List<Device> discoveredDevices,
  ) {
    final merged = <String, Device>{};
    final seenAt = DateTime.now().toUtc();
    for (final Device device in discoveredDevices) {
      merged[device.id] = device.copyWith(
        lastSeenAt: seenAt,
      );
    }
    for (final Device device in pairedDevices) {
      final existing = merged[device.id];
      merged[device.id] = existing == null
          ? device
          : existing.copyWith(
              name: device.name,
              accessToken: device.accessToken,
              websocketPath: existing.websocketPath,
              serviceType: existing.serviceType,
              wakeTarget: existing.wakeTarget ?? device.wakeTarget,
              networkRoutes: mergeNetworkRoutes(
                device.networkRoutes,
                existing.networkRoutes,
              ),
              routePolicy: device.routePolicy == DeviceRoutePolicy.inherit
                  ? existing.routePolicy
                  : device.routePolicy,
              preferredRouteHost:
                  device.preferredRouteHost ?? existing.preferredRouteHost,
              lastSuccessfulRouteHost: device.lastSuccessfulRouteHost ??
                  existing.lastSuccessfulRouteHost,
              lastFailedRouteHost:
                  device.lastFailedRouteHost ?? existing.lastFailedRouteHost,
              lastSeenAt: existing.lastSeenAt ?? device.lastSeenAt,
              lastConnectedAt:
                  device.lastConnectedAt ?? existing.lastConnectedAt,
              lastFailedAt: device.lastFailedAt ?? existing.lastFailedAt,
              lastFailureMessage:
                  device.lastFailureMessage ?? existing.lastFailureMessage,
            );
    }
    return merged.values.toList();
  }

  List<RemoteLayout> _mergeRemoteLayouts(
    List<RemoteLayout> bundled,
    List<RemoteLayout> cached,
    List<RemoteLayout> designed,
  ) {
    final merged = <String, RemoteLayout>{};
    for (final RemoteLayout remote in bundled) {
      merged[remote.id] = remote;
    }
    for (final RemoteLayout remote in cached) {
      merged[remote.id] = remote;
    }
    for (final RemoteLayout remote in designed) {
      merged[remote.id] = remote;
    }
    return merged.values.toList();
  }

  Future<void> _saveDesignedRemote(RemoteLayout remote) async {
    setState(() {
      _designedRemoteLayouts = <RemoteLayout>[
        remote,
        ..._designedRemoteLayouts.where(
          (RemoteLayout existing) => existing.id != remote.id,
        ),
      ];
      _remotes = _mergeRemoteLayouts(
        _bundledRemotes,
        _cachedRemoteLayouts,
        _designedRemoteLayouts,
      );
      _favoriteRemoteIds = <String>{..._favoriteRemoteIds, remote.id};
      _status = 'Saved designer remote ${remote.name}';
    });
    await _persistState();
  }

  Future<void> _deleteDesignedRemote(RemoteLayout remote) async {
    setState(() {
      _designedRemoteLayouts = _designedRemoteLayouts
          .where((RemoteLayout existing) => existing.id != remote.id)
          .toList();
      _favoriteRemoteIds = <String>{..._favoriteRemoteIds}..remove(remote.id);
      _remotes = _mergeRemoteLayouts(
        _bundledRemotes,
        _cachedRemoteLayouts,
        _designedRemoteLayouts,
      );
      _status = 'Deleted designer remote ${remote.name}';
    });
    await _persistState();
  }

  List<Device> _replaceOrInsertDevice(Device device) {
    final devices = <Device>[
      device,
      ..._devices.where((Device existing) => existing.id != device.id),
    ];
    return devices;
  }

  List<String> _recordRecentDevice(String deviceID) {
    return <String>[
      deviceID,
      ..._recentDeviceIds.where((String existing) => existing != deviceID),
    ].take(8).toList();
  }

  Device _recordConnectionSuccess(
    Device device, {
    required String routeHost,
    bool rememberRoute = false,
  }) {
    final now = DateTime.now().toUtc();
    final currentRoute = device.routeForHost(routeHost) ??
        NetworkRoute(
          host: routeHost,
          friendlyName: routeHost,
          kind: inferNetworkKindFromHost(routeHost),
          wakeTarget: device.wakeTarget,
        );

    return deviceWithRoute(
      device.copyWith(
        lastSeenAt: now,
        lastConnectedAt: now,
        lastSuccessfulRouteHost: routeHost,
        clearLastFailedRouteHost: true,
        clearLastFailedAt: true,
        clearLastFailureMessage: true,
      ),
      currentRoute,
      markPreferred: rememberRoute,
    );
  }

  Device _recordConnectionFailure(
    Device device, {
    required String routeHost,
    required Object error,
  }) {
    return device.copyWith(
      lastFailedRouteHost: routeHost,
      lastFailedAt: DateTime.now().toUtc(),
      lastFailureMessage: '$error',
      lastSeenAt: DateTime.now().toUtc(),
    );
  }

  List<Device> _orderedDevices() {
    final devices = List<Device>.from(_devices);
    devices.sort((Device left, Device right) {
      final leftFavorite = _favoriteDeviceIds.contains(left.id);
      final rightFavorite = _favoriteDeviceIds.contains(right.id);
      if (leftFavorite != rightFavorite) {
        return leftFavorite ? -1 : 1;
      }

      final leftRecent = _recentDeviceIds.indexOf(left.id);
      final rightRecent = _recentDeviceIds.indexOf(right.id);
      if (leftRecent != rightRecent) {
        if (leftRecent == -1) {
          return 1;
        }
        if (rightRecent == -1) {
          return -1;
        }
        return leftRecent.compareTo(rightRecent);
      }

      final leftPaired = (left.accessToken ?? '').isNotEmpty;
      final rightPaired = (right.accessToken ?? '').isNotEmpty;
      if (leftPaired != rightPaired) {
        return leftPaired ? -1 : 1;
      }

      return left.name.compareTo(right.name);
    });
    return devices;
  }

  List<RemoteLayout> _orderedRemotes() {
    final remotes = List<RemoteLayout>.from(_remotes);
    remotes.sort((RemoteLayout left, RemoteLayout right) {
      final leftFavorite = _favoriteRemoteIds.contains(left.id);
      final rightFavorite = _favoriteRemoteIds.contains(right.id);
      if (leftFavorite != rightFavorite) {
        return leftFavorite ? -1 : 1;
      }
      return left.name.compareTo(right.name);
    });
    return remotes;
  }

  List<SharedMediaFile> _mergeSharedFiles(
    List<SharedMediaFile> existing,
    List<SharedMediaFile> incoming,
  ) {
    final merged = <String, SharedMediaFile>{};
    for (final SharedMediaFile item in existing) {
      merged['${item.type.value}:${item.path}'] = item;
    }
    for (final SharedMediaFile item in incoming) {
      merged['${item.type.value}:${item.path}'] = item;
    }
    return merged.values.toList();
  }

  Future<void> _send(CommandEnvelope command) async {
    if (command.commandName == 'power_wake') {
      final device = _selectedDevice;
      if (device == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a device to wake first.')),
        );
        return;
      }

      await _wakeDevice(device);
      return;
    }

    if (_selectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connect to an agent first.')),
      );
      return;
    }
    if (!_client.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('The agent is offline. Wake it or reconnect first.'),
        ),
      );
      return;
    }

    try {
      await _client.send(command);
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Sent ${command.commandName}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Send failed';
      });

      unawaited(
        _reportClientError(
          error,
          screen: 'commands',
          action: command.commandName,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Command failed: $error')),
      );
    }
  }

  Future<void> _reportClientError(
    Object error, {
    StackTrace? stack,
    String? screen,
    String? action,
    Map<String, dynamic>? context,
  }) async {
    final device = _selectedDevice;
    if (device == null) {
      return;
    }

    await _apiClient.reportClientLog(
      device,
      level: 'error',
      message: action == null ? 'client error' : 'client error: $action',
      error: error,
      stack: stack,
      screen: screen,
      action: action,
      context: context,
    );
  }

  @override
  void dispose() {
    _client.connectionState.removeListener(_connectionListener);
    _reconnectTimer?.cancel();
    _shareIntentSub?.cancel();
    _client.dispose();
    super.dispose();
  }

  void _setSection(_AppSection section) {
    if (_currentSection == section) {
      return;
    }
    setState(() {
      _currentSection = section;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deviceLabel = _selectedDevice?.name ?? 'No agent selected';
    final orderedDevices = _orderedDevices();
    final orderedRemotes = _orderedRemotes();

    final sections = <Widget>[
      DeviceListScreen(
        devices: orderedDevices,
        selectedDevice: _selectedDevice,
        favoriteDeviceIds: _favoriteDeviceIds,
        recentDeviceIds: _recentDeviceIds,
        statusMessage: _status,
        isConnected: _client.isConnected,
        pendingSharedCount: _pendingSharedFiles.length,
        onConnect: _connectToDevice,
        onPairUriSubmit: _pairWithUri,
        onToggleFavoriteDevice: _toggleFavoriteDevice,
        onRefreshDevices: _refreshDevices,
        onOpenDeviceManager: () => _setSection(_AppSection.devices),
      ),
      DeviceManagerScreen(
        devices: orderedDevices,
        selectedDevice: _selectedDevice,
        favoriteDeviceIds: _favoriteDeviceIds,
        recentDeviceIds: _recentDeviceIds,
        statusMessage: _status,
        preferLocalRoutes: _preferLocalRoutes,
        onConnect: _connectToDevice,
        onPairUriSubmit: _pairWithUri,
        onToggleFavoriteDevice: _toggleFavoriteDevice,
        onDeleteDevice: _deleteDevice,
        onRefreshDevices: _refreshDevices,
        onSetPreferredRoute: _setPreferredRoute,
        onSetRoutePolicy: _setRoutePolicy,
        onPreferLocalRoutesChanged: _setPreferLocalRoutes,
      ),
      MouseScreen(
        enabled: _client.isConnected,
        onSend: _send,
      ),
      KeyboardScreen(
        enabled: _client.isConnected,
        onSend: _send,
      ),
      MediaScreen(
        enabled: _client.isConnected,
        onSend: _send,
      ),
      PowerScreen(
        device: _selectedDevice,
        isConnected: _client.isConnected,
        onSend: _send,
      ),
      FileExplorerScreen(
        enabled: _client.isConnected && _selectedDevice != null,
        device: _selectedDevice,
        apiClient: _apiClient,
      ),
      TaskManagerScreen(
        enabled: _client.isConnected && _selectedDevice != null,
        device: _selectedDevice,
        apiClient: _apiClient,
      ),
      ServicesScreen(
        enabled: _client.isConnected && _selectedDevice != null,
        device: _selectedDevice,
        apiClient: _apiClient,
      ),
      SystemInfoScreen(
        enabled: _client.isConnected && _selectedDevice != null,
        device: _selectedDevice,
        apiClient: _apiClient,
      ),
      FileTransferScreen(
        enabled: _client.isConnected && _selectedDevice != null,
        device: _selectedDevice,
        apiClient: _apiClient,
        pendingSharedCount: _pendingSharedFiles.length,
        onUploadPendingShares: _flushPendingShares,
      ),
      UpdatesScreen(
        service: _updatesService,
      ),
      CustomRemoteScreen(
        enabled: _selectedDevice != null,
        remotes: orderedRemotes,
        favoriteRemoteIds: _favoriteRemoteIds,
        onSend: _send,
        onToggleFavoriteRemote: _toggleFavoriteRemote,
      ),
      RemoteDesignerScreen(
        designedRemotes: List<RemoteLayout>.from(
          _designedRemoteLayouts,
        )..sort(
            (RemoteLayout left, RemoteLayout right) =>
                left.name.compareTo(right.name),
          ),
        onSaveRemote: _saveDesignedRemote,
        onDeleteRemote: _deleteDesignedRemote,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(_currentSection.title),
            Text(
              deviceLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6F6559),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
        actions: _loading
            ? null
            : <Widget>[
                IconButton(
                  onPressed: _refreshDevices,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh discovery',
                ),
                IconButton(
                  onPressed: _openDeviceSelector,
                  icon: const Icon(Icons.devices),
                  tooltip: 'Select device',
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Center(
                    child: ConnectionStatusPill(
                      state: _client.connectionState.value,
                    ),
                  ),
                ),
              ],
      ),
      drawer: _loading
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Container(
                          width: double.infinity,
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
                                'OpenRemote',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                deviceLabel,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _status,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: const Color(0xFFFDF2E6),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        children: <Widget>[
                          const _DrawerSectionLabel('Workspace'),
                          _DrawerItem(
                            section: _AppSection.dashboard,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.dashboard);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.devices,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.devices);
                            },
                          ),
                          const SizedBox(height: 12),
                          const _DrawerSectionLabel('Controls'),
                          _DrawerItem(
                            section: _AppSection.mouse,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.mouse);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.keyboard,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.keyboard);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.media,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.media);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.power,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.power);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.custom,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.custom);
                            },
                          ),
                          const SizedBox(height: 12),
                          const _DrawerSectionLabel('Tools'),
                          _DrawerItem(
                            section: _AppSection.explorer,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.explorer);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.tasks,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.tasks);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.services,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.services);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.system,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.system);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.files,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.files);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.updates,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.updates);
                            },
                          ),
                          _DrawerItem(
                            section: _AppSection.designer,
                            currentSection: _currentSection,
                            onTap: () {
                              Navigator.of(context).pop();
                              _setSection(_AppSection.designer);
                            },
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Use Device Manager to curate LAN and VPN pairings, remove stale desktops, and choose what stays on this phone.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _AppSection.values.indexOf(_currentSection),
              children: sections,
            ),
    );
  }
}

class _UploadPayload {
  const _UploadPayload({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final List<int> bytes;
}

class _PairingRouteChoice {
  const _PairingRouteChoice.auto() : network = null;

  const _PairingRouteChoice.network(this.network);

  final PairingNetworkOption? network;

  bool get isAuto => network == null;
}

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF6F6559),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.section,
    required this.currentSection,
    required this.onTap,
  });

  final _AppSection section;
  final _AppSection currentSection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = section == currentSection;

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      selected: isSelected,
      selectedTileColor: const Color(0xFFF2E4D0),
      leading: Icon(section.icon),
      title: Text(section.title),
      onTap: onTap,
    );
  }
}
