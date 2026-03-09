import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/models/device.dart';
import '../../core/networking/api_client.dart';
import '../../ui/widgets/remote_button.dart';

class FileTransferScreen extends StatefulWidget {
  const FileTransferScreen({
    super.key,
    required this.enabled,
    required this.device,
    required this.apiClient,
    required this.pendingSharedCount,
    required this.onUploadPendingShares,
  });

  final bool enabled;
  final Device? device;
  final ApiClient apiClient;
  final int pendingSharedCount;
  final Future<void> Function() onUploadPendingShares;

  @override
  State<FileTransferScreen> createState() => _FileTransferScreenState();
}

class _FileTransferScreenState extends State<FileTransferScreen> {
  bool _uploading = false;
  String _status = 'Pick a file to send it to the connected agent.';

  Future<void> _pickAndUpload() async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) {
      return;
    }

    final selected = result.files.single;
    final bytes = selected.bytes ??
        (selected.path != null
            ? await File(selected.path!).readAsBytes()
            : null);
    if (bytes == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Could not read file bytes.';
      });
      return;
    }

    setState(() {
      _uploading = true;
      _status = 'Uploading ${selected.name}';
    });

    try {
      final response = await widget.apiClient.uploadFile(
        device,
        fileName: selected.name,
        bytes: bytes,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Uploaded ${response['name']} (${response['size']} bytes)';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Upload failed';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(_status, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          if (widget.pendingSharedCount > 0) ...<Widget>[
            Text(
              '${widget.pendingSharedCount} shared item(s) waiting to upload.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            RemoteButton(
              label: 'Upload Pending Shares',
              enabled: widget.enabled && !_uploading,
              onPressed: widget.onUploadPendingShares,
            ),
            const SizedBox(height: 12),
          ],
          RemoteButton(
            label: _uploading ? 'Uploading...' : 'Choose File',
            enabled: widget.enabled && !_uploading,
            onPressed: _pickAndUpload,
          ),
        ],
      ),
    );
  }
}
