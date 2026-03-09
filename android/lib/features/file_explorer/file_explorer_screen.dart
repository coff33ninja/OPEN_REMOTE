import 'package:flutter/material.dart';

import '../../core/models/agent_data.dart';
import '../../core/models/device.dart';
import '../../core/networking/api_client.dart';

class FileExplorerScreen extends StatefulWidget {
  const FileExplorerScreen({
    super.key,
    required this.enabled,
    required this.device,
    required this.apiClient,
  });

  final bool enabled;
  final Device? device;
  final ApiClient apiClient;

  @override
  State<FileExplorerScreen> createState() => _FileExplorerScreenState();
}

class _FileExplorerScreenState extends State<FileExplorerScreen> {
  String _path = '';
  bool _loading = false;
  List<FileSystemEntry> _entries = const <FileSystemEntry>[];
  String _status = 'Connect to an agent to browse files.';

  @override
  void didUpdateWidget(covariant FileExplorerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.device?.id != oldWidget.device?.id && widget.enabled) {
      _path = '';
      _load();
    }
  }

  Future<void> _load([String? nextPath]) async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    setState(() {
      _loading = true;
      if (nextPath != null) {
        _path = nextPath;
      }
      _status = _path.isEmpty ? 'Loading roots' : 'Loading $_path';
    });

    try {
      final entries = await widget.apiClient.fetchDirectory(
        device,
        pathValue: _path,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _status = _path.isEmpty ? 'Drive roots' : _path;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Browse failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File explorer failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
            onPressed: widget.enabled && !_loading ? () => _load() : null,
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (BuildContext context, int index) {
              final entry = _entries[index];
              return ListTile(
                leading:
                    Icon(entry.isDir ? Icons.folder : Icons.insert_drive_file),
                title: Text(entry.name),
                subtitle: Text(entry.path),
                trailing: entry.isDir
                    ? IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _load(entry.path),
                      )
                    : Text('${entry.size} B'),
              );
            },
          ),
        ),
      ],
    );
  }
}
