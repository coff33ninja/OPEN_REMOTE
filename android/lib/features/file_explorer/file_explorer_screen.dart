import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

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
  static const Set<String> _textPreviewExtensions = <String>{
    '.bat',
    '.cmd',
    '.conf',
    '.cfg',
    '.csv',
    '.dart',
    '.go',
    '.ini',
    '.json',
    '.log',
    '.md',
    '.ps1',
    '.py',
    '.txt',
    '.xml',
    '.yaml',
    '.yml',
  };

  static const Set<String> _imagePreviewExtensions = <String>{
    '.bmp',
    '.gif',
    '.jpeg',
    '.jpg',
    '.png',
    '.webp',
  };

  String _path = '';
  String _searchQuery = '';
  bool _loading = false;
  String? _busyPath;
  List<FileSystemEntry> _entries = const <FileSystemEntry>[];
  String _status = 'Connect to an agent to browse files.';

  @override
  void initState() {
    super.initState();
    if (widget.enabled && widget.device != null) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant FileExplorerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final deviceChanged = widget.device?.id != oldWidget.device?.id;
    final enabledChanged = widget.enabled != oldWidget.enabled;

    if (!widget.enabled || widget.device == null) {
      setState(() {
        _entries = const <FileSystemEntry>[];
        _path = '';
        _searchQuery = '';
        _status = 'Connect to an agent to browse files.';
      });
      return;
    }

    if (deviceChanged) {
      _path = '';
      _searchQuery = '';
    }

    if ((deviceChanged || enabledChanged) && widget.enabled) {
      unawaited(_load(deviceChanged ? '' : null));
    }
  }

  List<FileSystemEntry> get _visibleEntries {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _entries;
    }

    return _entries.where((FileSystemEntry entry) {
      return entry.name.toLowerCase().contains(query) ||
          entry.path.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  bool get _isBusy => _loading || _busyPath != null;

  bool get _canMutateCurrentDirectory =>
      widget.enabled && !_isBusy && _path.trim().isNotEmpty;

  String? get _parentPath => _resolveParentPath(_path);

  Future<void> _load([String? nextPath]) async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    final targetPath = nextPath ?? _path;
    setState(() {
      _loading = true;
      _path = targetPath;
      _status = targetPath.isEmpty ? 'Loading roots' : 'Loading $targetPath';
    });

    try {
      final entries = await widget.apiClient.fetchDirectory(
        device,
        pathValue: targetPath,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _status = targetPath.isEmpty ? 'Drive roots' : targetPath;
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

  Future<void> _runEntryAction(
    FileSystemEntry entry,
    Future<void> Function(Device device) action, {
    String? successMessage,
    bool refreshAfter = true,
  }) async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    setState(() {
      _busyPath = entry.path;
    });

    try {
      await action(device);
      if (!mounted) {
        return;
      }

      if (refreshAfter) {
        await _load();
      }

      if (!mounted || successMessage == null || successMessage.isEmpty) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPath = null;
        });
      }
    }
  }

  Future<void> _createFolder() async {
    final device = widget.device;
    if (!_canMutateCurrentDirectory || device == null) {
      return;
    }

    final folderName = await _promptForText(
      title: 'Create Folder',
      label: 'Folder name',
      actionLabel: 'Create',
    );
    if (folderName == null) {
      return;
    }

    setState(() {
      _busyPath = _path;
    });

    try {
      await widget.apiClient.createFolder(
        device,
        parentPath: _path,
        name: folderName,
      );
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created folder $folderName')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Create folder failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPath = null;
        });
      }
    }
  }

  Future<void> _uploadIntoCurrentFolder() async {
    final device = widget.device;
    if (!_canMutateCurrentDirectory || device == null) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file bytes.')),
      );
      return;
    }

    setState(() {
      _busyPath = _path;
    });

    try {
      final response = await widget.apiClient.uploadFile(
        device,
        fileName: selected.name,
        bytes: bytes,
        targetDirectory: _path,
      );
      if (!mounted) {
        return;
      }
      await _load();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded ${response['name']} to $_path')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPath = null;
        });
      }
    }
  }

  Future<void> _renameEntry(FileSystemEntry entry) async {
    final nextName = await _promptForText(
      title: 'Rename ${entry.name}',
      label: 'New name',
      initialValue: entry.name,
      actionLabel: 'Rename',
    );
    if (nextName == null) {
      return;
    }

    await _runEntryAction(
      entry,
      (Device device) => widget.apiClient.renameEntry(
        device,
        entryPath: entry.path,
        newName: nextName,
      ),
      successMessage: 'Renamed to $nextName',
    );
  }

  Future<void> _deleteEntry(FileSystemEntry entry) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Delete ${entry.name}?'),
              content: Text(
                entry.isDir
                    ? 'This will remove the folder and everything inside it.'
                    : 'This will permanently remove the file.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!shouldDelete) {
      return;
    }

    await _runEntryAction(
      entry,
      (Device device) => widget.apiClient.deleteEntry(
        device,
        entryPath: entry.path,
      ),
      successMessage: 'Deleted ${entry.name}',
    );
  }

  Future<void> _moveOrCopyEntry(
    FileSystemEntry entry, {
    required bool copy,
  }) async {
    final destination = await _promptForDestination(
      entry: entry,
      actionLabel: copy ? 'Copy' : 'Move',
    );
    if (destination == null) {
      return;
    }

    await _runEntryAction(
      entry,
      (Device device) => copy
          ? widget.apiClient.copyEntry(
              device,
              sourcePath: entry.path,
              destinationPath: destination,
            )
          : widget.apiClient.moveEntry(
              device,
              sourcePath: entry.path,
              destinationPath: destination,
            ),
      successMessage:
          '${copy ? 'Copied' : 'Moved'} ${entry.name} to ${_displayDestination(destination)}',
    );
  }

  Future<void> _launchOnDesktop(FileSystemEntry entry) async {
    await _runEntryAction(
      entry,
      (Device device) => widget.apiClient.openRemotePath(
        device,
        entryPath: entry.path,
      ),
      successMessage: 'Launched ${entry.name} on the desktop',
      refreshAfter: false,
    );
  }

  Future<void> _previewEntry(FileSystemEntry entry) async {
    final extension = _fileExtension(entry.name);
    final canPreviewText = _textPreviewExtensions.contains(extension);
    final canPreviewImage = _imagePreviewExtensions.contains(extension);
    if (!canPreviewText && !canPreviewImage) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preview is not available for ${entry.name}.')),
      );
      return;
    }

    await _runEntryAction(
      entry,
      (Device device) async {
        final bytes = await widget.apiClient.downloadFile(
          device,
          remotePath: entry.path,
        );
        if (!mounted) {
          return;
        }
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (BuildContext context) {
            return _FilePreviewSheet(
              entry: entry,
              bytes: Uint8List.fromList(bytes),
              isImage: canPreviewImage,
            );
          },
        );
      },
      refreshAfter: false,
    );
  }

  Future<void> _downloadEntry(FileSystemEntry entry) async {
    final device = widget.device;
    if (!widget.enabled || device == null) {
      return;
    }

    final destinationDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose a folder for ${entry.name}',
    );
    if (destinationDirectory == null || destinationDirectory.isEmpty) {
      return;
    }

    setState(() {
      _busyPath = entry.path;
    });

    try {
      final bytes = await widget.apiClient.downloadFile(
        device,
        remotePath: entry.path,
      );
      final outputPath = path.join(destinationDirectory, entry.name);
      await File(outputPath).writeAsBytes(bytes, flush: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${entry.name} to $outputPath')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyPath = null;
        });
      }
    }
  }

  Future<void> _handleEntryTap(FileSystemEntry entry) async {
    if (entry.isDir) {
      await _load(entry.path);
      return;
    }

    final extension = _fileExtension(entry.name);
    if (_textPreviewExtensions.contains(extension) ||
        _imagePreviewExtensions.contains(extension)) {
      await _previewEntry(entry);
      return;
    }

    await _downloadEntry(entry);
  }

  Future<String?> _promptForText({
    required String title,
    required String label,
    required String actionLabel,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );
    final normalized = result?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  Future<String?> _promptForDestination({
    required FileSystemEntry entry,
    required String actionLabel,
  }) async {
    final folderController = TextEditingController(text: _path);
    final nameController = TextEditingController(text: entry.name);

    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('$actionLabel ${entry.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: folderController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Destination folder',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name at destination',
                ),
                onSubmitted: (_) => Navigator.of(context).pop(
                  _joinRemotePath(
                    folderController.text.trim(),
                    nameController.text.trim(),
                  ),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                _joinRemotePath(
                  folderController.text.trim(),
                  nameController.text.trim(),
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        );
      },
    );

    final normalized = result?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String _joinRemotePath(String directory, String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      return directory.trim();
    }

    if (directory.trim().isEmpty) {
      return cleanName;
    }

    final context = _remotePathContext(directory);
    return context.join(directory, cleanName);
  }

  String? _resolveParentPath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final context = _remotePathContext(trimmed);
    final normalized = _normalizeRemotePath(trimmed);
    final parent = context.dirname(normalized);
    if (parent == normalized) {
      return '';
    }
    if (parent == '.' || parent.isEmpty) {
      return '';
    }
    if (_looksLikeWindowsPath(normalized) &&
        RegExp(r'^[A-Za-z]:$').hasMatch(parent)) {
      return '$parent\\';
    }
    return parent;
  }

  List<_PathCrumb> _breadcrumbsFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <_PathCrumb>[];
    }

    final normalized = _normalizeRemotePath(trimmed);
    if (_looksLikeWindowsPath(normalized)) {
      final driveMatch = RegExp(r'^([A-Za-z]:)\\?').firstMatch(normalized);
      if (driveMatch == null) {
        return const <_PathCrumb>[];
      }

      final driveRoot = '${driveMatch.group(1)}\\';
      final crumbs = <_PathCrumb>[
        _PathCrumb(label: driveRoot, path: driveRoot),
      ];
      final rest = normalized.substring(driveRoot.length);
      var current = driveRoot;
      for (final part in rest.split('\\')) {
        if (part.isEmpty) {
          continue;
        }
        current = current.endsWith('\\') ? '$current$part' : '$current\\$part';
        crumbs.add(_PathCrumb(label: part, path: current));
      }
      return crumbs;
    }

    final parts = normalized.split('/').where((String part) => part.isNotEmpty);
    final crumbs = <_PathCrumb>[
      const _PathCrumb(label: '/', path: '/'),
    ];
    var current = '';
    for (final part in parts) {
      current = current.isEmpty ? '/$part' : '$current/$part';
      crumbs.add(_PathCrumb(label: part, path: current));
    }
    return crumbs;
  }

  path.Context _remotePathContext(String value) {
    return path.Context(
      style:
          _looksLikeWindowsPath(value) ? path.Style.windows : path.Style.posix,
    );
  }

  bool _looksLikeWindowsPath(String value) {
    return value.contains('\\') || RegExp(r'^[A-Za-z]:').hasMatch(value);
  }

  String _normalizeRemotePath(String value) {
    final trimmed = value.trim();
    final context = _remotePathContext(trimmed);
    final normalized = context.normalize(trimmed);
    if (_looksLikeWindowsPath(trimmed) &&
        RegExp(r'^[A-Za-z]:$').hasMatch(normalized)) {
      return '$normalized\\';
    }
    return normalized;
  }

  String _fileExtension(String name) {
    final lastDot = name.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == name.length - 1) {
      return '';
    }
    return name.substring(lastDot).toLowerCase();
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

  String _formatModified(String value) {
    if (value.trim().isEmpty) {
      return 'Unknown date';
    }
    final timestamp = DateTime.tryParse(value)?.toLocal();
    if (timestamp == null) {
      return value;
    }

    final iso = timestamp.toIso8601String();
    final parts = iso.split('T');
    final date = parts.first;
    final time = parts.length > 1 ? parts.last.substring(0, 5) : '';
    return '$date $time'.trim();
  }

  String _displayDestination(String destination) {
    final context = _remotePathContext(destination);
    return context.dirname(destination);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _visibleEntries;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _status,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Refresh',
                        onPressed:
                            widget.enabled && !_isBusy ? () => _load() : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ActionChip(
                        label: const Text('Roots'),
                        avatar: const Icon(Icons.dns_outlined, size: 18),
                        onPressed:
                            widget.enabled && !_isBusy ? () => _load('') : null,
                      ),
                      ..._breadcrumbsFor(_path).map(
                        (_PathCrumb crumb) => ActionChip(
                          label: Text(crumb.label),
                          onPressed: widget.enabled && !_isBusy
                              ? () => _load(crumb.path)
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    enabled: widget.enabled,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Filter this directory',
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (String value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed:
                            widget.enabled && !_isBusy && _parentPath != null
                                ? () => _load(_parentPath)
                                : null,
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Up'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            _canMutateCurrentDirectory ? _createFolder : null,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('New Folder'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _canMutateCurrentDirectory
                            ? _uploadIntoCurrentFolder
                            : null,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Upload Here'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_isBusy) const LinearProgressIndicator(),
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.trim().isEmpty
                        ? (_path.isEmpty
                            ? 'No roots available.'
                            : 'This folder is empty.')
                        : 'No entries match "$_searchQuery".',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final entry = entries[index];
                    final extension = _fileExtension(entry.name);
                    final previewable =
                        _textPreviewExtensions.contains(extension) ||
                            _imagePreviewExtensions.contains(extension);
                    final entryBusy = _busyPath == entry.path;

                    return Card(
                      child: ListTile(
                        leading: Icon(
                          entry.isDir
                              ? Icons.folder_outlined
                              : previewable
                                  ? Icons.visibility_outlined
                                  : Icons.insert_drive_file_outlined,
                        ),
                        title: Text(entry.name),
                        subtitle: Text(
                          entry.isDir
                              ? entry.path
                              : '${_formatBytes(entry.size)} • ${_formatModified(entry.modified)}\n${entry.path}',
                        ),
                        isThreeLine: !entry.isDir,
                        trailing: entryBusy
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : PopupMenuButton<_FileEntryAction>(
                                onSelected: (_FileEntryAction action) async {
                                  switch (action) {
                                    case _FileEntryAction.open:
                                      await _handleEntryTap(entry);
                                    case _FileEntryAction.launch:
                                      await _launchOnDesktop(entry);
                                    case _FileEntryAction.preview:
                                      await _previewEntry(entry);
                                    case _FileEntryAction.download:
                                      await _downloadEntry(entry);
                                    case _FileEntryAction.rename:
                                      await _renameEntry(entry);
                                    case _FileEntryAction.copy:
                                      await _moveOrCopyEntry(entry, copy: true);
                                    case _FileEntryAction.move:
                                      await _moveOrCopyEntry(entry,
                                          copy: false);
                                    case _FileEntryAction.delete:
                                      await _deleteEntry(entry);
                                  }
                                },
                                itemBuilder: (BuildContext context) =>
                                    <PopupMenuEntry<_FileEntryAction>>[
                                  PopupMenuItem<_FileEntryAction>(
                                    value: _FileEntryAction.open,
                                    child: Text(
                                        entry.isDir ? 'Open Folder' : 'Open'),
                                  ),
                                  const PopupMenuItem<_FileEntryAction>(
                                    value: _FileEntryAction.launch,
                                    child: Text('Launch on Desktop'),
                                  ),
                                  if (!entry.isDir && previewable)
                                    const PopupMenuItem<_FileEntryAction>(
                                      value: _FileEntryAction.preview,
                                      child: Text('Preview'),
                                    ),
                                  if (!entry.isDir)
                                    const PopupMenuItem<_FileEntryAction>(
                                      value: _FileEntryAction.download,
                                      child: Text('Download'),
                                    ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem<_FileEntryAction>(
                                    value: _FileEntryAction.rename,
                                    child: Text('Rename'),
                                  ),
                                  const PopupMenuItem<_FileEntryAction>(
                                    value: _FileEntryAction.copy,
                                    child: Text('Copy To...'),
                                  ),
                                  const PopupMenuItem<_FileEntryAction>(
                                    value: _FileEntryAction.move,
                                    child: Text('Move To...'),
                                  ),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem<_FileEntryAction>(
                                    value: _FileEntryAction.delete,
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                        onTap: () => _handleEntryTap(entry),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

enum _FileEntryAction {
  open,
  launch,
  preview,
  download,
  rename,
  copy,
  move,
  delete,
}

class _PathCrumb {
  const _PathCrumb({
    required this.label,
    required this.path,
  });

  final String label;
  final String path;
}

class _FilePreviewSheet extends StatelessWidget {
  const _FilePreviewSheet({
    required this.entry,
    required this.bytes,
    required this.isImage,
  });

  final FileSystemEntry entry;
  final Uint8List bytes;
  final bool isImage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              entry.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(entry.path),
            const SizedBox(height: 16),
            Flexible(
              child: isImage
                  ? Center(child: Image.memory(bytes, fit: BoxFit.contain))
                  : SingleChildScrollView(
                      child: SelectableText(
                        utf8.decode(bytes, allowMalformed: true),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
