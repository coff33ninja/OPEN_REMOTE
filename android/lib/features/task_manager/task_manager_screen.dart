import 'package:flutter/material.dart';

import '../../core/models/agent_data.dart';
import '../../core/models/device.dart';
import '../../core/networking/api_client.dart';

class TaskManagerScreen extends StatefulWidget {
  const TaskManagerScreen({
    super.key,
    required this.enabled,
    required this.device,
    required this.apiClient,
  });

  final bool enabled;
  final Device? device;
  final ApiClient apiClient;

  @override
  State<TaskManagerScreen> createState() => _TaskManagerScreenState();
}

class _TaskManagerScreenState extends State<TaskManagerScreen> {
  bool _loading = false;
  List<AgentProcess> _processes = const <AgentProcess>[];
  String _status = 'Connect to an agent to view processes.';

  @override
  void didUpdateWidget(covariant TaskManagerScreen oldWidget) {
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
      _status = 'Loading processes';
    });

    try {
      final processes = await widget.apiClient.fetchProcesses(device);
      if (!mounted) {
        return;
      }
      setState(() {
        _processes = processes;
        _status = '${processes.length} processes';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Process list failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task manager failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _confirmTerminate(AgentProcess process) async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    final shouldTerminate = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Terminate process?'),
            content: Text(
              'End ${process.name} (PID ${process.pid}) on the connected agent?',
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Terminate'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldTerminate) {
      return;
    }

    try {
      await widget.apiClient.terminateProcess(device, process.pid);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Termination requested for ${process.name}')),
      );
      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terminate failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        ListTile(
          title: Text(_status),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.enabled && !_loading ? _load : null,
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: _processes.length,
            itemBuilder: (BuildContext context, int index) {
              final process = _processes[index];
              return ListTile(
                dense: true,
                title: Text(process.name),
                subtitle: Text('PID ${process.pid}  ${process.memory}'),
                trailing: IconButton(
                  icon: const Icon(Icons.cancel_schedule_send),
                  onPressed: () => _confirmTerminate(process),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
