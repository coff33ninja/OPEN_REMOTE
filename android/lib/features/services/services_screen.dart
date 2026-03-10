import 'package:flutter/material.dart';

import '../../core/models/agent_data.dart';
import '../../core/models/device.dart';
import '../../core/networking/api_client.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({
    super.key,
    required this.enabled,
    required this.device,
    required this.apiClient,
  });

  final bool enabled;
  final Device? device;
  final ApiClient apiClient;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  bool _loading = false;
  List<AgentService> _services = const <AgentService>[];
  String _status = 'Connect to an agent to view services.';
  String _filter = '';

  @override
  void didUpdateWidget(covariant ServicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device?.id != oldWidget.device?.id && widget.enabled) {
      _load();
    }
  }

  Future<void> _load() async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Loading services';
    });

    try {
      final services = await widget.apiClient.fetchServices(device);
      if (!mounted) {
        return;
      }
      setState(() {
        _services = services;
        _status = '${services.length} services';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Service list failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Services failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  List<AgentService> get _visibleServices {
    final query = _filter.trim().toLowerCase();
    if (query.isEmpty) {
      return _services;
    }
    return _services
        .where((AgentService service) =>
            service.name.toLowerCase().contains(query) ||
            service.displayName.toLowerCase().contains(query))
        .toList(growable: false);
  }

  Future<void> _runAction(
    AgentService service,
    Future<void> Function(Device device) action,
    String successLabel,
  ) async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    try {
      await action(device);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$successLabel ${service.name}')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = _visibleServices;

    return Column(
      children: <Widget>[
        ListTile(
          title: Text(_status),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.enabled && !_loading ? _load : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            enabled: widget.enabled,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Filter services',
              suffixIcon: _filter.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () => setState(() => _filter = ''),
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (String value) {
              setState(() {
                _filter = value;
              });
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: services.length,
            itemBuilder: (BuildContext context, int index) {
              final service = services[index];
              final status =
                  service.status.trim().isEmpty ? 'Unknown' : service.status;
              final startType = service.startType.trim().isEmpty
                  ? 'Unknown'
                  : service.startType;

              return ListTile(
                title: Text(service.displayName.isEmpty
                    ? service.name
                    : service.displayName),
                subtitle: Text('${service.name} • $status • $startType'),
                trailing: PopupMenuButton<_ServiceAction>(
                  onSelected: (_ServiceAction action) async {
                    switch (action) {
                      case _ServiceAction.start:
                        await _runAction(
                          service,
                          (Device device) => widget.apiClient
                              .startService(device, service.name),
                          'Start requested for',
                        );
                      case _ServiceAction.stop:
                        await _runAction(
                          service,
                          (Device device) => widget.apiClient
                              .stopService(device, service.name),
                          'Stop requested for',
                        );
                      case _ServiceAction.restart:
                        await _runAction(
                          service,
                          (Device device) => widget.apiClient
                              .restartService(device, service.name),
                          'Restart requested for',
                        );
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<_ServiceAction>>[
                    const PopupMenuItem<_ServiceAction>(
                      value: _ServiceAction.start,
                      child: Text('Start'),
                    ),
                    const PopupMenuItem<_ServiceAction>(
                      value: _ServiceAction.stop,
                      child: Text('Stop'),
                    ),
                    const PopupMenuItem<_ServiceAction>(
                      value: _ServiceAction.restart,
                      child: Text('Restart'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

enum _ServiceAction {
  start,
  stop,
  restart,
}
