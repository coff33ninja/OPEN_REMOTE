import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/agent_data.dart';
import '../../core/models/device.dart';
import '../../core/networking/api_client.dart';

class SystemInfoScreen extends StatefulWidget {
  const SystemInfoScreen({
    super.key,
    required this.enabled,
    required this.device,
    required this.apiClient,
  });

  final bool enabled;
  final Device? device;
  final ApiClient apiClient;

  @override
  State<SystemInfoScreen> createState() => _SystemInfoScreenState();
}

class _SystemInfoScreenState extends State<SystemInfoScreen> {
  static const Duration _refreshInterval = Duration(seconds: 5);
  Timer? _refreshTimer;
  bool _loading = false;
  bool _showSpinner = false;
  String _status = 'Connect to an agent to view system info.';
  String? _error;
  AgentSystemSnapshot? _snapshot;

  @override
  void initState() {
    super.initState();
    _configureRefresh();
  }

  @override
  void didUpdateWidget(covariant SystemInfoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled ||
        widget.device?.id != oldWidget.device?.id) {
      _configureRefresh();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _configureRefresh() {
    _refreshTimer?.cancel();
    if (!widget.enabled || widget.device == null) {
      setState(() {
        _snapshot = null;
        _error = null;
        _loading = false;
        _status = 'Connect to an agent to view system info.';
      });
      return;
    }

    _load(showSpinner: true);
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!_loading) {
        _load();
      }
    });
  }

  Future<void> _load({bool showSpinner = false}) async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    setState(() {
      _loading = true;
      _showSpinner = showSpinner;
      _error = null;
      if (showSpinner) {
        _status = 'Loading system info';
      }
    });

    try {
      final snapshot = await widget.apiClient.fetchSystemSnapshot(device);
      if (!mounted) {
        return;
      }
      final observedAt = snapshot.observedAt;
      setState(() {
        _snapshot = snapshot;
        _status = observedAt == null
            ? 'System info updated'
            : 'Updated ${_formatTimestamp(observedAt)}';
        _error = snapshot.cacheError.trim().isEmpty
            ? null
            : snapshot.cacheError.trim();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'System info failed';
        _error = 'System info failed: $error';
      });
    } finally {
      if (mounted && _loading) {
        setState(() {
          _loading = false;
          _showSpinner = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;

    return Column(
      children: <Widget>[
        ListTile(
          title: Text(_status),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.enabled && !_loading
                ? () => _load(showSpinner: true)
                : null,
          ),
        ),
        if (_showSpinner) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              _error ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.redAccent),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: <Widget>[
              _buildCpuCard(snapshot),
              const SizedBox(height: 12),
              _buildMemoryCard(snapshot),
              const SizedBox(height: 12),
              _buildGpuCard(snapshot),
              const SizedBox(height: 12),
              _buildThermalCard(snapshot),
              const SizedBox(height: 12),
              _buildDiskCard(snapshot),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCpuCard(AgentSystemSnapshot? snapshot) {
    final cpus = snapshot?.cpus ?? const <AgentCpuInfo>[];
    final coreStats = snapshot?.cpuCores ?? const <AgentCpuCoreInfo>[];
    if (cpus.isEmpty) {
      return _emptyCard('CPU', 'No CPU data reported.');
    }

    final totalLoad = cpus.fold<int>(0, (sum, cpu) => sum + cpu.loadPercent);
    final avgLoad = (totalLoad / cpus.length).toStringAsFixed(1);

    final coreWidgets = <Widget>[];
    if (coreStats.isNotEmpty) {
      final chips = coreStats
          .map(
            (AgentCpuCoreInfo core) => Chip(
              visualDensity: VisualDensity.compact,
              label: Text(_formatCoreLabel(core)),
            ),
          )
          .toList(growable: false);
      coreWidgets
        ..add(const SizedBox(height: 12))
        ..add(
          Text(
            'Per-core load',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )
        ..add(const SizedBox(height: 8))
        ..add(Wrap(spacing: 8, runSpacing: 8, children: chips));
    }

    return _sectionCard(
      title: 'CPU',
      subtitle: 'Average load $avgLoad%',
      children: <Widget>[
        ...cpus
            .map(
              (AgentCpuInfo cpu) => ListTile(
                dense: true,
                title: Text(cpu.name.isEmpty ? 'CPU' : cpu.name),
                subtitle: Text(
                  [
                    if (cpu.vendor.trim().isNotEmpty) cpu.vendor,
                    if (cpu.architecture.trim().isNotEmpty) cpu.architecture,
                    '${cpu.loadPercent}% load',
                    '${cpu.cores} cores',
                    '${cpu.logicalCores} threads',
                    '${cpu.maxMHz} MHz',
                  ].join(' • '),
                ),
              ),
            )
            .toList(growable: false),
        ...coreWidgets,
      ],
    );
  }

  Widget _buildMemoryCard(AgentSystemSnapshot? snapshot) {
    final memory = snapshot?.memory;
    if (memory == null) {
      return _emptyCard('Memory', 'No memory data reported.');
    }

    final usedPercent = memory.usedPercent.clamp(0, 100).toStringAsFixed(1);
    final usedRatio =
        memory.totalBytes <= 0 ? 0 : memory.usedBytes / memory.totalBytes;

    return _sectionCard(
      title: 'Memory',
      subtitle:
          '${_formatBytes(memory.usedBytes)} used of ${_formatBytes(memory.totalBytes)} ($usedPercent%)',
      children: <Widget>[
        LinearProgressIndicator(value: usedRatio.clamp(0, 1).toDouble()),
        const SizedBox(height: 8),
        Text('Free ${_formatBytes(memory.freeBytes)}'),
      ],
    );
  }

  Widget _buildGpuCard(AgentSystemSnapshot? snapshot) {
    final gpus = snapshot?.gpus ?? const <AgentGpuInfo>[];
    final gpuMemory = snapshot?.gpuMemory;
    if (gpus.isEmpty) {
      return _emptyCard('GPU', 'No GPU data reported.');
    }

    final memoryLines = <String>[
      if (gpuMemory != null && gpuMemory.dedicatedUsedBytes > 0)
        'Dedicated used ${_formatBytes(gpuMemory.dedicatedUsedBytes)}',
      if (gpuMemory != null && gpuMemory.sharedUsedBytes > 0)
        'Shared used ${_formatBytes(gpuMemory.sharedUsedBytes)}',
      if (gpuMemory != null && gpuMemory.totalCommittedBytes > 0)
        'Committed ${_formatBytes(gpuMemory.totalCommittedBytes)}',
    ];

    return _sectionCard(
      title: 'GPU',
      children: <Widget>[
        if (memoryLines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(memoryLines.join(' • ')),
          ),
        ...gpus
            .map(
              (AgentGpuInfo gpu) => ListTile(
                dense: true,
                title: Text(gpu.name.isEmpty ? 'GPU' : gpu.name),
                subtitle: Text(
                  [
                    if (gpu.adapterBytes > 0)
                      'VRAM ${_formatBytes(gpu.adapterBytes)}',
                    if (gpu.driver.trim().isNotEmpty) 'Driver ${gpu.driver}',
                  ].join(' • '),
                ),
              ),
            )
            .toList(growable: false),
      ],
    );
  }

  Widget _buildThermalCard(AgentSystemSnapshot? snapshot) {
    final thermals = snapshot?.thermals ?? const <AgentThermalZoneInfo>[];
    if (thermals.isEmpty) {
      return _emptyCard('Thermals', 'No thermal data reported.');
    }

    return _sectionCard(
      title: 'Thermals',
      children: thermals
          .map(
            (AgentThermalZoneInfo zone) => ListTile(
              dense: true,
              title: Text(zone.name.isEmpty ? 'Thermal' : zone.name),
              trailing: Text('${zone.temperatureC.toStringAsFixed(1)}°C'),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildDiskCard(AgentSystemSnapshot? snapshot) {
    final disks = snapshot?.disks ?? const <AgentDiskInfo>[];
    if (disks.isEmpty) {
      return _emptyCard('Drives', 'No disk data reported.');
    }

    return _sectionCard(
      title: 'Drives',
      children: disks.map(
        (AgentDiskInfo disk) {
          final usedRatio =
              disk.totalBytes <= 0 ? 0 : disk.usedBytes / disk.totalBytes;
          final label = disk.label.trim().isEmpty
              ? disk.name
              : '${disk.name} • ${disk.label}';
          final meta = [
            if (disk.driveType.trim().isNotEmpty) disk.driveType,
            if (disk.fileSystem.trim().isNotEmpty) disk.fileSystem,
          ].join(' • ');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: usedRatio.clamp(0, 1).toDouble(),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatBytes(disk.usedBytes)} used of ${_formatBytes(disk.totalBytes)} • ${disk.freePercent.toStringAsFixed(1)}% free',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
      ).toList(growable: false),
    );
  }

  Widget _emptyCard(String title, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(subtitle),
            ],
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final iso = local.toIso8601String();
    final parts = iso.split('T');
    final date = parts.first;
    final time = parts.length > 1 ? parts.last.substring(0, 5) : '';
    return '$date $time'.trim();
  }

  String _formatCoreLabel(AgentCpuCoreInfo core) {
    final id = core.id.trim().isEmpty ? 'Core' : 'Core ${core.id.trim()}';
    final kind = core.kind.trim();
    final suffix = kind.isEmpty ? '' : ' ($kind)';
    return '$id$suffix: ${core.usagePercent}%';
  }
}
