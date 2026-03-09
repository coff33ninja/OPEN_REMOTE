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
import 'core/networking/discovery.dart';
import 'core/networking/pairing_host_resolver.dart';
import 'core/networking/wake_on_lan_client.dart';
import 'core/networking/websocket_client.dart';
import 'core/persistence/app_state_store.dart';
import 'features/custom_remotes/remote_loader.dart';
import 'features/custom_remotes/remote_renderer.dart';
import 'features/discovery/device_list.dart';
import 'features/file_transfer/file_transfer_screen.dart';
import 'features/file_explorer/file_explorer_screen.dart';
import 'features/keyboard_remote/keyboard_screen.dart';
import 'features/media_remote/media_screen.dart';
import 'features/mouse_remote/mouse_screen.dart';
import 'features/remote_designer/remote_designer_screen.dart';
import 'features/task_manager/task_manager_screen.dart';
import 'ui/themes/app_theme.dart';

void main() {
  runApp(const OpenRemoteApp());
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
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _bootstrap();
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
    if (device.accessToken == null || device.accessToken!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Pair this device first using an OpenRemote pair URI.')),
      );
      return;
    }

    setState(() {
      _status = 'Connecting to ${device.name}';
    });

    try {
      final resolvedDevice = await _apiClient.fetchMeta(device);
      await _client.connect(
        resolvedDevice.websocketUrl,
        accessToken: resolvedDevice.accessToken,
      );
      final remoteCatalog = await _apiClient.fetchRemoteCatalog(resolvedDevice);
      if (!mounted) {
        return;
      }

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
        _selectedDevice = resolvedDevice;
        _cachedRemoteLayouts =
            remoteCatalog.isNotEmpty ? remoteCatalog : _cachedRemoteLayouts;
        _remotes = mergedRemotes;
        _devices = _replaceOrInsertDevice(resolvedDevice);
        _recentDeviceIds = _recordRecentDevice(resolvedDevice.id);
        _status = announceRestore
            ? 'Connected to ${resolvedDevice.name}'
            : 'Restored ${resolvedDevice.name}';
      });

      await _persistState();
      await _flushPendingShares();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Connection failed';
      });

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
      _selectedDevice = device;
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
      await _connectToDevice(pairedDevice);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Pairing failed';
      });

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
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
                  'Wake-capable LAN routes are listed separately from remote-only routes such as VPN addresses.',
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
                      option.canWake ? Icons.wifi : Icons.vpn_key,
                    ),
                    title: Text(option.displayName),
                    subtitle: Text(
                      '${option.host} • ${option.canWake ? 'Wake-on-LAN available' : 'No Wake-on-LAN'}',
                    ),
                    onTap: () => Navigator.of(context).pop(
                      _PairingRouteChoice.network(option),
                    ),
                  ),
              ],
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
    final candidates = pairingHostCandidates(pairing, _devices);

    for (final candidate in candidates) {
      try {
        return await _apiClient.completePairing(
            candidate, 'OpenRemote Android');
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
      } catch (_) {
        remaining.add(item);
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
      ),
    );
  }

  List<Device> _mergeDevices(
    List<Device> pairedDevices,
    List<Device> discoveredDevices,
  ) {
    final merged = <String, Device>{};
    for (final Device device in discoveredDevices) {
      merged[device.id] = device;
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Command failed: $error')),
      );
    }
  }

  @override
  void dispose() {
    _shareIntentSub?.cancel();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceLabel = _selectedDevice?.name ?? 'No agent selected';
    final orderedDevices = _orderedDevices();
    final orderedRemotes = _orderedRemotes();

    return DefaultTabController(
      length: 9,
      child: Scaffold(
        appBar: AppBar(
          title: Text('OpenRemote - $deviceLabel'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Discover'),
              Tab(text: 'Mouse'),
              Tab(text: 'Keyboard'),
              Tab(text: 'Media'),
              Tab(text: 'Explorer'),
              Tab(text: 'Tasks'),
              Tab(text: 'Files'),
              Tab(text: 'Custom'),
              Tab(text: 'Designer'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: <Widget>[
                  DeviceListScreen(
                    devices: orderedDevices,
                    selectedDevice: _selectedDevice,
                    favoriteDeviceIds: _favoriteDeviceIds,
                    recentDeviceIds: _recentDeviceIds,
                    statusMessage: _status,
                    onConnect: _connectToDevice,
                    onWake: _wakeDevice,
                    onPairUriSubmit: _pairWithUri,
                    onToggleFavoriteDevice: _toggleFavoriteDevice,
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
                  FileTransferScreen(
                    enabled: _client.isConnected && _selectedDevice != null,
                    device: _selectedDevice,
                    apiClient: _apiClient,
                    pendingSharedCount: _pendingSharedFiles.length,
                    onUploadPendingShares: _flushPendingShares,
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
                ],
              ),
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
