import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/remote_layout.dart';
import '../custom_remotes/remote_renderer.dart';

class RemoteDesignerScreen extends StatelessWidget {
  const RemoteDesignerScreen({
    super.key,
    required this.designedRemotes,
    required this.onSaveRemote,
    required this.onDeleteRemote,
  });

  final List<RemoteLayout> designedRemotes;
  final Future<void> Function(RemoteLayout remote) onSaveRemote;
  final Future<void> Function(RemoteLayout remote) onDeleteRemote;

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
                  'Remote Designer',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Build local remotes on a drag-and-drop canvas, preview them live, and save them on this device.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const Key('create-remote-button'),
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Remote'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (designedRemotes.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No locally designed remotes yet. Create one and it will be saved on this device.',
              ),
            ),
          )
        else
          ...designedRemotes.map(
            (RemoteLayout remote) => Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      remote.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${remote.category} • ${remote.layout.length} controls'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: () => _openEditor(context, remote: remote),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => _copyJson(context, remote),
                          icon: const Icon(Icons.content_copy),
                          label: const Text('Copy JSON'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => onDeleteRemote(remote),
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    RemoteLayout? remote,
  }) async {
    final savedRemote = await Navigator.of(context).push<RemoteLayout>(
      MaterialPageRoute<RemoteLayout>(
        builder: (BuildContext context) =>
            RemoteDesignerEditorScreen(initialRemote: remote),
      ),
    );
    if (savedRemote != null) {
      await onSaveRemote(savedRemote);
    }
  }

  Future<void> _copyJson(BuildContext context, RemoteLayout remote) async {
    await Clipboard.setData(
      ClipboardData(
        text: const JsonEncoder.withIndent('  ').convert(remote.toJson()),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied ${remote.name} JSON')),
      );
    }
  }
}

class RemoteDesignerEditorScreen extends StatefulWidget {
  const RemoteDesignerEditorScreen({
    this.initialRemote,
  });

  final RemoteLayout? initialRemote;

  @override
  State<RemoteDesignerEditorScreen> createState() =>
      _RemoteDesignerEditorScreenState();
}

class _RemoteDesignerEditorScreenState
    extends State<RemoteDesignerEditorScreen> {
  late final TextEditingController _idController;
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _controlIdController;
  late final TextEditingController _labelController;
  late final TextEditingController _commandController;
  late final TextEditingController _minController;
  late final TextEditingController _maxController;
  late final TextEditingController _stepController;
  late final TextEditingController _propsController;
  late final TextEditingController _xController;
  late final TextEditingController _yController;
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;

  late List<RemoteControl> _controls;
  late RemoteCanvas _canvas;
  int? _selectedIndex;
  String? _propsError;

  @override
  void initState() {
    super.initState();
    final remote = widget.initialRemote;
    _canvas = remote?.canvas ?? RemoteCanvas.defaultCanvas;
    _controls = _materializeControlsForCanvas(
      remote?.layout ?? const <RemoteControl>[],
      _canvas,
    );
    _selectedIndex = _controls.isEmpty ? null : 0;
    _idController = TextEditingController(
      text: remote?.id ?? _newRemoteId(),
    );
    _nameController = TextEditingController(
      text: remote?.name ?? 'New Remote',
    );
    _categoryController = TextEditingController(
      text: remote?.category ?? 'custom',
    );
    _controlIdController = TextEditingController();
    _labelController = TextEditingController();
    _commandController = TextEditingController();
    _minController = TextEditingController();
    _maxController = TextEditingController();
    _stepController = TextEditingController();
    _propsController = TextEditingController();
    _xController = TextEditingController();
    _yController = TextEditingController();
    _widthController = TextEditingController();
    _heightController = TextEditingController();
    _hydrateSelectedControlEditors();
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _controlIdController.dispose();
    _labelController.dispose();
    _commandController.dispose();
    _minController.dispose();
    _maxController.dispose();
    _stepController.dispose();
    _propsController.dispose();
    _xController.dispose();
    _yController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  RemoteLayout get _previewRemote => RemoteLayout(
        id: _idController.text.trim().isEmpty
            ? _newRemoteId()
            : _idController.text.trim(),
        name: _nameController.text.trim().isEmpty
            ? 'Untitled Remote'
            : _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'custom'
            : _categoryController.text.trim(),
        canvas: _canvas,
        layout: _controls,
      );

  RemoteControl? get _selectedControl {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _controls.length) {
      return null;
    }
    return _controls[index];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.initialRemote == null ? 'Create Remote' : 'Edit Remote'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copy JSON',
            onPressed: _copyPreviewJson,
            icon: const Icon(Icons.content_copy),
          ),
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final leftColumn = <Widget>[
            _buildMetadataCard(context),
            const SizedBox(height: 16),
            _buildPaletteCard(context),
            const SizedBox(height: 16),
            _buildCanvasCard(context),
          ];
          final rightColumn = <Widget>[
            _buildInspectorCard(context),
            const SizedBox(height: 16),
            _buildPreviewCard(context),
          ];

          if (constraints.maxWidth >= 1100) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 3,
                    child: Column(children: leftColumn),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(children: rightColumn),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              ...leftColumn,
              const SizedBox(height: 16),
              ...rightColumn,
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetadataCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Remote Metadata',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'These values become the saved remote definition and feed the live preview.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('remote-id-field'),
              controller: _idController,
              decoration: const InputDecoration(labelText: 'Remote ID'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('remote-name-field'),
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Remote Name'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('remote-category-field'),
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text(
              'Canvas ${_canvas.width.round()} x ${_canvas.height.round()} • grid ${_canvas.gridSize.round()}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaletteCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Palette',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Drag a control type onto the canvas. Drop onto a tile to place before it, or use the add slot to append.',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _controlPalette.map((spec) {
                return _PaletteControlCard(
                  spec: spec,
                  onTap: () => _insertNewControl(spec.type),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Canvas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Text('${_controls.length} controls'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Drag a control from the palette onto the surface. Drag placed controls to move them and use the inspector for exact frame values.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final width =
                    constraints.maxWidth.clamp(280.0, 860.0).toDouble();
                return Center(
                  child: SizedBox(
                    width: width,
                    child: AspectRatio(
                      aspectRatio: _canvas.width / _canvas.height,
                      child: LayoutBuilder(
                        builder: (
                          BuildContext canvasContext,
                          BoxConstraints canvasConstraints,
                        ) {
                          final surfaceSize = Size(
                            canvasConstraints.maxWidth,
                            canvasConstraints.maxHeight,
                          );
                          final scaleX = surfaceSize.width / _canvas.width;
                          final scaleY = surfaceSize.height / _canvas.height;

                          return DragTarget<_CanvasDragData>(
                            key: const Key('designer-canvas-surface'),
                            onAcceptWithDetails:
                                (DragTargetDetails<_CanvasDragData> details) {
                              final renderBox =
                                  canvasContext.findRenderObject() as RenderBox;
                              final localOffset =
                                  renderBox.globalToLocal(details.offset);
                              _insertControlAtOffset(
                                details.data.type,
                                localOffset,
                                surfaceSize,
                              );
                            },
                            builder: (
                              BuildContext context,
                              List<_CanvasDragData?> candidateData,
                              List<dynamic> rejectedData,
                            ) {
                              final isHovered = candidateData.isNotEmpty;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                decoration: BoxDecoration(
                                  color: isHovered
                                      ? const Color(0xFFE7F7D7)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: isHovered
                                        ? const Color(0xFF65A30D)
                                        : const Color(0xFFCBD5E1),
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _DesignerGridPainter(
                                            gridSpacingX:
                                                _canvas.gridSize * scaleX,
                                            gridSpacingY:
                                                _canvas.gridSize * scaleY,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_controls.isEmpty)
                                      const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              Icons.space_dashboard_outlined,
                                              size: 40,
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                                'Drop a control onto the canvas'),
                                          ],
                                        ),
                                      ),
                                    for (var index = 0;
                                        index < _controls.length;
                                        index++)
                                      _buildCanvasNode(index, scaleX, scaleY),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCanvasNode(int index, double scaleX, double scaleY) {
    final control = _controls[index];
    final frame =
        control.frame ?? _defaultFrameForIndex(control.type, index, _canvas);
    final spec = _specForType(control.type);
    final isSelected = index == _selectedIndex;

    return Positioned(
      left: frame.x * scaleX,
      top: frame.y * scaleY,
      width: frame.width * scaleX,
      height: frame.height * scaleY,
      child: GestureDetector(
        key: Key('canvas-node-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectControl(index),
        onPanUpdate: (DragUpdateDetails details) {
          _moveControlBy(index, details.delta, scaleX, scaleY);
        },
        child: _CanvasControlTile(
          control: control,
          spec: spec,
          isSelected: isSelected,
          isHovered: false,
          index: index,
        ),
      ),
    );
  }

  Widget _buildInspectorCard(BuildContext context) {
    final selected = _selectedControl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Inspector',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (selected == null)
              const Text(
                'Select a canvas tile to edit its behavior, bindings, and advanced properties.',
              )
            else ...<Widget>[
              Text(
                'Editing tile ${_selectedIndex! + 1}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('selected-control-type-field'),
                initialValue: selected.type,
                decoration: const InputDecoration(labelText: 'Control Type'),
                items: _controlPalette.map((spec) {
                  return DropdownMenuItem<String>(
                    value: spec.type,
                    child: Text(spec.label),
                  );
                }).toList(),
                onChanged: _changeSelectedControlType,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('selected-control-id-field'),
                controller: _controlIdController,
                decoration: const InputDecoration(labelText: 'Control ID'),
                onChanged: (String value) {
                  _updateSelectedControl((RemoteControl current) {
                    return _copyControl(
                      current,
                      id: value.trim().isEmpty
                          ? 'control-${(_selectedIndex ?? 0) + 1}'
                          : value.trim(),
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('selected-control-label-field'),
                controller: _labelController,
                decoration: const InputDecoration(labelText: 'Label'),
                onChanged: (String value) {
                  _updateSelectedControl((RemoteControl current) {
                    return _copyControl(
                      current,
                      label: value.trim().isEmpty ? null : value.trim(),
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('selected-control-command-field'),
                controller: _commandController,
                decoration: const InputDecoration(labelText: 'Command'),
                onChanged: (String value) {
                  _updateSelectedControl((RemoteControl current) {
                    return _copyControl(
                      current,
                      command: value.trim().isEmpty ? 'noop' : value.trim(),
                    );
                  });
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('selected-control-x-field'),
                      controller: _xController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'X'),
                      onChanged: (String value) {
                        _updateSelectedFrame(x: _parseDouble(value));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('selected-control-y-field'),
                      controller: _yController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Y'),
                      onChanged: (String value) {
                        _updateSelectedFrame(y: _parseDouble(value));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      key: const Key('selected-control-width-field'),
                      controller: _widthController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Width'),
                      onChanged: (String value) {
                        _updateSelectedFrame(width: _parseDouble(value));
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('selected-control-height-field'),
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Height'),
                      onChanged: (String value) {
                        _updateSelectedFrame(height: _parseDouble(value));
                      },
                    ),
                  ),
                ],
              ),
              if (selected.type == 'slider') ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('selected-control-min-field'),
                        controller: _minController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Min'),
                        onChanged: (String value) {
                          _updateSelectedControl((RemoteControl current) {
                            return _copyControl(
                              current,
                              min: _parseDouble(value),
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('selected-control-max-field'),
                        controller: _maxController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Max'),
                        onChanged: (String value) {
                          _updateSelectedControl((RemoteControl current) {
                            return _copyControl(
                              current,
                              max: _parseDouble(value),
                            );
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        key: const Key('selected-control-step-field'),
                        controller: _stepController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(labelText: 'Step'),
                        onChanged: (String value) {
                          _updateSelectedControl((RemoteControl current) {
                            return _copyControl(
                              current,
                              step: _parseDouble(value),
                            );
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                key: const Key('selected-control-props-field'),
                controller: _propsController,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  labelText: 'Props JSON',
                  helperText:
                      'Use JSON objects for bindings, macro steps, grid buttons, and advanced control options.',
                  errorText: _propsError,
                ),
                onChanged: _onPropsChanged,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: _duplicateSelectedControl,
                    icon: const Icon(Icons.copy),
                    label: const Text('Duplicate'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _deleteSelectedControl,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Live Preview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _copyPreviewJson,
                  icon: const Icon(Icons.copy_all),
                  label: const Text('Copy JSON'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Preview uses the production renderer, so saved controls behave the same way in the Custom tab.',
            ),
            const SizedBox(height: 16),
            CustomRemoteScreen(
              enabled: false,
              remotes: <RemoteLayout>[_previewRemote],
              favoriteRemoteIds: const <String>{},
              onSend: (_) async {},
              onToggleFavoriteRemote: (_) async {},
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
            ),
          ],
        ),
      ),
    );
  }

  void _selectControl(int index) {
    setState(() {
      _selectedIndex = index;
      _hydrateSelectedControlEditors();
    });
  }

  void _insertNewControl(String type) {
    final control = _defaultControl(type, _controls.length + 1).copyWith(
      frame: _nextAvailableFrame(type),
    );

    setState(() {
      _controls.add(control);
      _selectedIndex = _controls.length - 1;
      _hydrateSelectedControlEditors();
    });
  }

  void _insertControlAtOffset(
    String type,
    Offset localOffset,
    Size surfaceSize,
  ) {
    final seeded = _defaultControl(type, _controls.length + 1);
    final prototype = seeded.frame ?? _defaultFrameForType(type);
    final logicalX = (localOffset.dx / surfaceSize.width * _canvas.width) -
        (prototype.width / 2);
    final logicalY = (localOffset.dy / surfaceSize.height * _canvas.height) -
        (prototype.height / 2);
    final positioned = seeded.copyWith(
      frame: _clampFrame(
        prototype.copyWith(
          x: logicalX,
          y: logicalY,
        ),
      ),
    );

    setState(() {
      _controls.add(positioned);
      _selectedIndex = _controls.length - 1;
      _hydrateSelectedControlEditors();
    });
  }

  void _moveControlBy(int index, Offset delta, double scaleX, double scaleY) {
    final control = _controls[index];
    final frame =
        control.frame ?? _defaultFrameForIndex(control.type, index, _canvas);

    setState(() {
      _controls[index] = control.copyWith(
        frame: _clampFrame(
          frame.copyWith(
            x: frame.x + (delta.dx / scaleX),
            y: frame.y + (delta.dy / scaleY),
          ),
        ),
      );
      _selectedIndex = index;
      _hydrateSelectedControlEditors();
    });
  }

  RemoteFrame _nextAvailableFrame(String type) {
    final prototype = _defaultFrameForType(type);
    if (_controls.isEmpty) {
      return _clampFrame(
        prototype.copyWith(
          x: _canvas.gridSize,
          y: _canvas.gridSize,
        ),
      );
    }

    final maxBottom = _controls
        .map((RemoteControl control) =>
            (control.frame ?? _defaultFrameForType(control.type)).y +
            (control.frame ?? _defaultFrameForType(control.type)).height)
        .fold<double>(_canvas.gridSize, (double maxValue, double current) {
      return current > maxValue ? current : maxValue;
    });

    return _clampFrame(
      prototype.copyWith(
        x: _canvas.gridSize,
        y: maxBottom + _canvas.gridSize,
      ),
    );
  }

  RemoteFrame _clampFrame(RemoteFrame frame) {
    final width = frame.width.clamp(120.0, _canvas.width).toDouble();
    final height = frame.height.clamp(88.0, _canvas.height).toDouble();
    return frame.copyWith(
      width: width,
      height: height,
      x: frame.x.clamp(0.0, _canvas.width - width).toDouble(),
      y: frame.y.clamp(0.0, _canvas.height - height).toDouble(),
    );
  }

  void _changeSelectedControlType(String? nextType) {
    final selected = _selectedControl;
    final index = _selectedIndex;
    if (nextType == null || selected == null || index == null) {
      return;
    }

    final template = _defaultControl(nextType, index + 1);
    setState(() {
      _controls[index] = selected.copyWith(
        type: template.type,
        command: template.command,
        label: selected.label ?? template.label,
        min: template.min,
        max: template.max,
        step: template.step,
        props: template.props,
        frame: _clampFrame(
          (selected.frame ??
                  _defaultFrameForIndex(selected.type, index, _canvas))
              .copyWith(
            width: (template.frame ?? _defaultFrameForType(nextType)).width,
            height: (template.frame ?? _defaultFrameForType(nextType)).height,
          ),
        ),
      );
      _hydrateSelectedControlEditors();
    });
  }

  void _updateSelectedControl(
    RemoteControl Function(RemoteControl current) transform,
  ) {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _controls.length) {
      return;
    }

    setState(() {
      _controls[index] = transform(_controls[index]);
    });
  }

  void _updateSelectedFrame({
    double? x,
    double? y,
    double? width,
    double? height,
  }) {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _controls.length) {
      return;
    }

    final control = _controls[index];
    final frame =
        control.frame ?? _defaultFrameForIndex(control.type, index, _canvas);

    setState(() {
      _controls[index] = control.copyWith(
        frame: _clampFrame(
          frame.copyWith(
            x: x ?? frame.x,
            y: y ?? frame.y,
            width: width ?? frame.width,
            height: height ?? frame.height,
          ),
        ),
      );
      _hydrateSelectedControlEditors();
    });
  }

  void _duplicateSelectedControl() {
    final selected = _selectedControl;
    final index = _selectedIndex;
    if (selected == null || index == null) {
      return;
    }

    final duplicate = _copyControl(
      selected,
      id: '${selected.id}-copy-${DateTime.now().millisecondsSinceEpoch}',
      frame: _clampFrame(
        (selected.frame ?? _defaultFrameForIndex(selected.type, index, _canvas))
            .copyWith(
          x: (selected.frame ??
                      _defaultFrameForIndex(selected.type, index, _canvas))
                  .x +
              _canvas.gridSize,
          y: (selected.frame ??
                      _defaultFrameForIndex(selected.type, index, _canvas))
                  .y +
              _canvas.gridSize,
        ),
      ),
    );

    setState(() {
      _controls.insert(index + 1, duplicate);
      _selectedIndex = index + 1;
      _hydrateSelectedControlEditors();
    });
  }

  void _deleteSelectedControl() {
    final index = _selectedIndex;
    if (index == null || index < 0 || index >= _controls.length) {
      return;
    }

    setState(() {
      _controls.removeAt(index);
      if (_controls.isEmpty) {
        _selectedIndex = null;
      } else if (index >= _controls.length) {
        _selectedIndex = _controls.length - 1;
      } else {
        _selectedIndex = index;
      }
      _hydrateSelectedControlEditors();
    });
  }

  void _hydrateSelectedControlEditors() {
    final selected = _selectedControl;
    _propsError = null;

    if (selected == null) {
      _controlIdController.clear();
      _labelController.clear();
      _commandController.clear();
      _minController.clear();
      _maxController.clear();
      _stepController.clear();
      _propsController.clear();
      _xController.clear();
      _yController.clear();
      _widthController.clear();
      _heightController.clear();
      return;
    }

    final frame = selected.frame ??
        _defaultFrameForIndex(selected.type, _selectedIndex ?? 0, _canvas);
    _controlIdController.text = selected.id;
    _labelController.text = selected.label ?? '';
    _commandController.text = selected.command;
    _minController.text = selected.min?.toString() ?? '';
    _maxController.text = selected.max?.toString() ?? '';
    _stepController.text = selected.step?.toString() ?? '';
    _xController.text = frame.x.round().toString();
    _yController.text = frame.y.round().toString();
    _widthController.text = frame.width.round().toString();
    _heightController.text = frame.height.round().toString();
    _propsController.text =
        const JsonEncoder.withIndent('  ').convert(selected.props);
  }

  void _onPropsChanged(String value) {
    final parsed = _tryParseProps(value);
    if (value.trim().isEmpty) {
      setState(() {
        _propsError = null;
      });
      _updateSelectedControl((RemoteControl current) {
        return _copyControl(current, props: const <String, dynamic>{});
      });
      return;
    }

    if (parsed == null) {
      setState(() {
        _propsError = 'Props must be a valid JSON object.';
      });
      return;
    }

    setState(() {
      _propsError = null;
      final index = _selectedIndex;
      if (index != null && index >= 0 && index < _controls.length) {
        _controls[index] = _copyControl(_controls[index], props: parsed);
      }
    });
  }

  Future<void> _copyPreviewJson() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            const JsonEncoder.withIndent('  ').convert(_previewRemote.toJson()),
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied remote JSON')),
    );
  }

  void _save() {
    final remote = _previewRemote;
    if (remote.layout.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one control before saving.'),
        ),
      );
      return;
    }
    if (_propsError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fix invalid props JSON before saving.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(remote);
  }
}

class _PaletteControlCard extends StatelessWidget {
  const _PaletteControlCard({
    required this.spec,
    required this.onTap,
  });

  final _ControlPaletteSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Draggable<_CanvasDragData>(
      data: _CanvasDragData.newControl(spec.type),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 220,
          child: _PaletteCardBody(spec: spec, compact: true),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.45,
        child: _PaletteCardBody(spec: spec),
      ),
      child: InkWell(
        key: Key('palette-${spec.type}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: _PaletteCardBody(spec: spec),
      ),
    );
  }
}

class _PaletteCardBody extends StatelessWidget {
  const _PaletteCardBody({
    required this.spec,
    this.compact = false,
  });

  final _ControlPaletteSpec spec;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: compact ? 220 : 196,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(spec.icon),
          const SizedBox(height: 12),
          Text(
            spec.label,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            spec.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CanvasControlTile extends StatelessWidget {
  const _CanvasControlTile({
    required this.control,
    required this.spec,
    required this.isSelected,
    required this.isHovered,
    required this.index,
  });

  final RemoteControl control;
  final _ControlPaletteSpec spec;
  final bool isSelected;
  final bool isHovered;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFDBEAFE)
            : isHovered
                ? const Color(0xFFDCFCE7)
                : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF2563EB)
              : isHovered
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFCBD5E1),
          width: isSelected || isHovered ? 2 : 1.2,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final compact =
              constraints.maxHeight < 120 || constraints.maxWidth < 240;

          if (compact) {
            return Row(
              children: <Widget>[
                Icon(spec.icon, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    control.label ?? spec.label,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '#${index + 1}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(spec.icon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      control.label ?? spec.label,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('#${index + 1}'),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                control.command,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                '${control.frame?.width.round() ?? 0} x ${control.frame?.height.round() ?? 0}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    label: Text(spec.label),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (control.props.isNotEmpty)
                    const Chip(
                      label: Text('Props'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CanvasDragData {
  const _CanvasDragData.newControl(this.type);

  final String type;
}

class _ControlPaletteSpec {
  const _ControlPaletteSpec({
    required this.type,
    required this.label,
    required this.description,
    required this.icon,
  });

  final String type;
  final String label;
  final String description;
  final IconData icon;
}

const List<_ControlPaletteSpec> _controlPalette = <_ControlPaletteSpec>[
  _ControlPaletteSpec(
    type: 'button',
    label: 'Button',
    description: 'Single-tap action buttons for media, presentation, and apps.',
    icon: Icons.smart_button_outlined,
  ),
  _ControlPaletteSpec(
    type: 'toggle',
    label: 'Toggle',
    description:
        'Stateful-feeling action button for play/pause style commands.',
    icon: Icons.toggle_on_outlined,
  ),
  _ControlPaletteSpec(
    type: 'slider',
    label: 'Slider',
    description: 'Continuous value control for volume, brightness, or zoom.',
    icon: Icons.tune,
  ),
  _ControlPaletteSpec(
    type: 'touchpad',
    label: 'Touchpad',
    description: 'Large gesture surface for mouse or pointer movement.',
    icon: Icons.touch_app_outlined,
  ),
  _ControlPaletteSpec(
    type: 'text_input',
    label: 'Text Input',
    description: 'Text box plus send action for keyboard typing commands.',
    icon: Icons.keyboard_alt_outlined,
  ),
  _ControlPaletteSpec(
    type: 'dpad',
    label: 'D-pad',
    description:
        'Five-way directional controls backed by per-direction bindings.',
    icon: Icons.gamepad_outlined,
  ),
  _ControlPaletteSpec(
    type: 'grid_buttons',
    label: 'Button Grid',
    description: 'Compact action matrix for meeting scenes or launcher pads.',
    icon: Icons.grid_view_outlined,
  ),
  _ControlPaletteSpec(
    type: 'macro_button',
    label: 'Macro',
    description: 'One tap that runs a multi-step workflow on the agent.',
    icon: Icons.auto_awesome_motion_outlined,
  ),
];

_ControlPaletteSpec _specForType(String type) {
  for (final spec in _controlPalette) {
    if (spec.type == type) {
      return spec;
    }
  }
  return _controlPalette.first;
}

RemoteControl _copyControl(
  RemoteControl control, {
  String? id,
  String? type,
  String? command,
  Object? label = _unset,
  Object? min = _unset,
  Object? max = _unset,
  Object? step = _unset,
  Map<String, dynamic>? props,
  Object? frame = _unset,
}) {
  return control.copyWith(
    id: id,
    type: type,
    command: command,
    label: label,
    min: min,
    max: max,
    step: step,
    props: props,
    frame: frame,
  );
}

const Object _unset = Object();

RemoteControl _defaultControl(String type, int index) {
  final id = '$type-$index';
  final frame = _defaultFrameForIndex(type, index - 1);
  switch (type) {
    case 'slider':
      return RemoteControl(
        id: id,
        type: type,
        command: 'volume_set',
        label: 'Slider $index',
        min: 0,
        max: 100,
        step: 5,
        frame: frame,
      );
    case 'touchpad':
      return RemoteControl(
        id: id,
        type: type,
        command: 'mouse_move',
        label: 'Touchpad $index',
        frame: frame,
      );
    case 'text_input':
      return RemoteControl(
        id: id,
        type: type,
        command: 'keyboard_type',
        label: 'Text Input $index',
        frame: frame,
      );
    case 'dpad':
      return RemoteControl(
        id: id,
        type: type,
        command: 'presentation_next',
        label: 'D-pad $index',
        frame: frame,
        props: <String, dynamic>{
          'up': <String, dynamic>{
            'label': 'Up',
            'command': 'volume_set',
            'props': <String, dynamic>{'value': 70},
          },
          'down': <String, dynamic>{
            'label': 'Down',
            'command': 'volume_set',
            'props': <String, dynamic>{'value': 20},
          },
          'left': <String, dynamic>{
            'label': 'Prev',
            'command': 'presentation_previous',
          },
          'right': <String, dynamic>{
            'label': 'Next',
            'command': 'presentation_next',
          },
          'center': <String, dynamic>{
            'label': 'Blank',
            'command': 'presentation_blackout',
          },
        },
      );
    case 'grid_buttons':
      return RemoteControl(
        id: id,
        type: type,
        command: 'media_toggle',
        label: 'Button Grid $index',
        frame: frame,
        props: <String, dynamic>{
          'columns': 2,
          'buttons': <Map<String, dynamic>>[
            <String, dynamic>{
              'label': 'Play',
              'command': 'media_toggle',
            },
            <String, dynamic>{
              'label': 'Stop',
              'command': 'media_stop',
            },
          ],
        },
      );
    case 'macro_button':
      return RemoteControl(
        id: id,
        type: type,
        command: 'macro_run',
        label: 'Macro $index',
        frame: frame,
        props: <String, dynamic>{
          'steps': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'volume_set',
              'arguments': <String, dynamic>{'value': 35},
            },
            <String, dynamic>{
              'name': 'media_toggle',
            },
          ],
        },
      );
    case 'toggle':
      return RemoteControl(
        id: id,
        type: type,
        command: 'media_toggle',
        label: 'Toggle $index',
        frame: frame,
      );
    case 'button':
    default:
      return RemoteControl(
        id: id,
        type: type,
        command: 'media_toggle',
        label: 'Button $index',
        frame: frame,
      );
  }
}

double? _parseDouble(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return double.tryParse(trimmed);
}

Map<String, dynamic>? _tryParseProps(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return const <String, dynamic>{};
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return null;
}

String _newRemoteId() {
  return 'custom-${DateTime.now().millisecondsSinceEpoch}';
}

class _DesignerGridPainter extends CustomPainter {
  const _DesignerGridPainter({
    required this.gridSpacingX,
    required this.gridSpacingY,
  });

  final double gridSpacingX;
  final double gridSpacingY;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x140F172A)
      ..strokeWidth = 1;

    if (gridSpacingX > 0) {
      for (double x = gridSpacingX; x < size.width; x += gridSpacingX) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }

    if (gridSpacingY > 0) {
      for (double y = gridSpacingY; y < size.height; y += gridSpacingY) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DesignerGridPainter oldDelegate) {
    return oldDelegate.gridSpacingX != gridSpacingX ||
        oldDelegate.gridSpacingY != gridSpacingY;
  }
}

List<RemoteControl> _materializeControlsForCanvas(
  List<RemoteControl> controls,
  RemoteCanvas canvas,
) {
  return controls.asMap().entries.map((MapEntry<int, RemoteControl> entry) {
    return entry.value.copyWith(
      frame: entry.value.frame ??
          _defaultFrameForIndex(entry.value.type, entry.key, canvas),
    );
  }).toList();
}

RemoteFrame _defaultFrameForType(String type) {
  switch (type) {
    case 'touchpad':
      return const RemoteFrame(x: 0, y: 0, width: 840, height: 340);
    case 'dpad':
      return const RemoteFrame(x: 0, y: 0, width: 420, height: 420);
    case 'grid_buttons':
      return const RemoteFrame(x: 0, y: 0, width: 720, height: 320);
    case 'text_input':
      return const RemoteFrame(x: 0, y: 0, width: 720, height: 180);
    case 'slider':
      return const RemoteFrame(x: 0, y: 0, width: 720, height: 120);
    case 'macro_button':
    case 'toggle':
    case 'button':
    default:
      return const RemoteFrame(x: 0, y: 0, width: 360, height: 120);
  }
}

RemoteFrame _defaultFrameForIndex(
  String type,
  int index, [
  RemoteCanvas canvas = RemoteCanvas.defaultCanvas,
]) {
  final prototype = _defaultFrameForType(type);
  final spacing = canvas.gridSize;
  final perColumn = 2;
  final column = index % perColumn;
  final row = index ~/ perColumn;
  final x = spacing + (column * (prototype.width + spacing));
  final y = spacing + (row * (prototype.height + spacing));

  return prototype.copyWith(
    x: x.clamp(0.0, canvas.width - prototype.width).toDouble(),
    y: y.clamp(0.0, canvas.height - prototype.height).toDouble(),
  );
}
