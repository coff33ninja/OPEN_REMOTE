import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/command.dart';
import '../../ui/widgets/remote_button.dart';

class KeyboardScreen extends StatefulWidget {
  const KeyboardScreen({
    super.key,
    required this.enabled,
    required this.onSend,
  });

  final bool enabled;
  final Future<void> Function(CommandEnvelope command) onSend;

  @override
  State<KeyboardScreen> createState() => _KeyboardScreenState();
}

class _KeyboardScreenState extends State<KeyboardScreen> {
  static const double _compactBreakpoint = 760;

  static const List<_KeyPreset> _editingKeys = <_KeyPreset>[
    _KeyPreset('Esc', 'esc'),
    _KeyPreset('Tab', 'tab'),
    _KeyPreset('Enter', 'enter'),
    _KeyPreset('Backspace', 'backspace'),
    _KeyPreset('Delete', 'delete'),
    _KeyPreset('Space', 'space'),
  ];

  static const List<_KeyPreset> _navigationKeys = <_KeyPreset>[
    _KeyPreset('Up', 'up'),
    _KeyPreset('Left', 'left'),
    _KeyPreset('Right', 'right'),
    _KeyPreset('Down', 'down'),
    _KeyPreset('Home', 'home'),
    _KeyPreset('End', 'end'),
    _KeyPreset('PgUp', 'pgup'),
    _KeyPreset('PgDn', 'pgdn'),
    _KeyPreset('Insert', 'insert'),
  ];

  static const List<_KeyPreset> _commonKeys = <_KeyPreset>[
    _KeyPreset('A', 'a'),
    _KeyPreset('C', 'c'),
    _KeyPreset('V', 'v'),
    _KeyPreset('X', 'x'),
    _KeyPreset('Y', 'y'),
    _KeyPreset('Z', 'z'),
    _KeyPreset('0', '0'),
    _KeyPreset('1', '1'),
    _KeyPreset('2', '2'),
    _KeyPreset('3', '3'),
    _KeyPreset('4', '4'),
    _KeyPreset('5', '5'),
  ];

  static const List<_KeyPreset> _quickKeys = <_KeyPreset>[
    _KeyPreset('Enter', 'enter'),
    _KeyPreset('Backspace', 'backspace'),
    _KeyPreset('Tab', 'tab'),
    _KeyPreset('Esc', 'esc'),
    _KeyPreset('Space', 'space'),
  ];

  static const List<_ShortcutPreset> _shortcuts = <_ShortcutPreset>[
    _ShortcutPreset('Alt+Tab', <String>['alt', 'tab']),
    _ShortcutPreset('Ctrl+Shift+Esc', <String>['ctrl', 'shift', 'esc']),
    _ShortcutPreset('Win+D', <String>['win', 'd']),
    _ShortcutPreset('Win+Tab', <String>['win', 'tab']),
  ];

  static const List<String> _modifiers = <String>[
    'ctrl',
    'alt',
    'shift',
    'win',
  ];

  final TextEditingController _textController = TextEditingController();
  final TextEditingController _singleKeyController = TextEditingController();
  final Set<String> _heldModifiers = <String>{};
  final FocusNode _textFocusNode = FocusNode();

  bool _liveImeMode = false;
  bool _suppressLiveSync = false;
  String _lastSyncedCommittedText = '';
  Future<void> _liveSyncQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    for (final String key in _heldModifiers.toList().reversed) {
      unawaited(
        _sendKeyboard(
          action: 'key_up',
          arguments: <String, dynamic>{'key': key},
        ),
      );
    }
    _textController.removeListener(_handleTextChanged);
    _textController.dispose();
    _singleKeyController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendKeyboard({
    required String action,
    Map<String, dynamic> arguments = const <String, dynamic>{},
  }) {
    return widget.onSend(
      CommandEnvelope(
        type: 'keyboard',
        action: action,
        arguments: arguments,
      ),
    );
  }

  Future<void> _submitText() async {
    if (!widget.enabled) {
      return;
    }

    if (_liveImeMode) {
      await _commitCurrentComposition();
      return;
    }

    final text = _committedText(_textController.value);
    if (text.isEmpty) {
      return;
    }

    await _sendKeyboard(
      action: 'type',
      arguments: <String, dynamic>{'text': text},
    );
    _textController.clear();
  }

  Future<void> _submitSingleKey() async {
    final key = _singleKeyController.text.trim();
    if (!widget.enabled || key.isEmpty) {
      return;
    }

    await _sendKeyboard(
      action: 'press',
      arguments: <String, dynamic>{'key': key},
    );
    _singleKeyController.clear();
  }

  Future<void> _pressKey(String key) async {
    if (!widget.enabled) {
      return;
    }

    await _sendKeyboard(
      action: 'press',
      arguments: <String, dynamic>{'key': key},
    );
  }

  Future<void> _toggleModifier(String key) async {
    if (!widget.enabled) {
      return;
    }

    final isHeld = _heldModifiers.contains(key);
    await _sendKeyboard(
      action: isHeld ? 'key_up' : 'key_down',
      arguments: <String, dynamic>{'key': key},
    );
    if (!mounted) {
      return;
    }
    setState(() {
      if (isHeld) {
        _heldModifiers.remove(key);
      } else {
        _heldModifiers.add(key);
      }
    });
  }

  Future<void> _releaseHeldModifiers() async {
    if (!widget.enabled || _heldModifiers.isEmpty) {
      return;
    }

    final keys = _heldModifiers.toList().reversed.toList(growable: false);
    for (final String key in keys) {
      await _sendKeyboard(
        action: 'key_up',
        arguments: <String, dynamic>{'key': key},
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _heldModifiers.clear();
    });
  }

  Future<void> _sendShortcut(List<String> keys) async {
    if (!widget.enabled) {
      return;
    }

    await _sendKeyboard(
      action: 'shortcut',
      arguments: <String, dynamic>{'keys': keys},
    );
  }

  void _handleTextChanged() {
    if (!_liveImeMode || _suppressLiveSync || !widget.enabled) {
      return;
    }

    final snapshot = _textController.value;
    _liveSyncQueue = _liveSyncQueue.then((_) => _syncCommittedText(snapshot));
  }

  Future<void> _commitCurrentComposition() async {
    final value = _textController.value;
    final composing = value.composing;
    if (!composing.isValid ||
        composing.isCollapsed ||
        composing.start < 0 ||
        composing.end > value.text.length) {
      return;
    }

    _suppressLiveSync = true;
    _textController.value = value.copyWith(
      text: value.text,
      composing: TextRange.empty,
      selection: TextSelection.collapsed(offset: composing.end),
    );
    _suppressLiveSync = false;

    if (_liveImeMode && widget.enabled) {
      await _syncCommittedText(_textController.value);
    }
  }

  Future<void> _syncCommittedText(TextEditingValue value) async {
    if (!_liveImeMode || !widget.enabled) {
      return;
    }

    final nextCommittedText = _committedText(value);
    if (nextCommittedText == _lastSyncedCommittedText) {
      return;
    }

    final oldChars =
        _lastSyncedCommittedText.characters.toList(growable: false);
    final newChars = nextCommittedText.characters.toList(growable: false);

    var prefix = 0;
    while (prefix < oldChars.length &&
        prefix < newChars.length &&
        oldChars[prefix] == newChars[prefix]) {
      prefix++;
    }

    var suffix = 0;
    while (suffix < oldChars.length - prefix &&
        suffix < newChars.length - prefix &&
        oldChars[oldChars.length - 1 - suffix] ==
            newChars[newChars.length - 1 - suffix]) {
      suffix++;
    }

    final tailOnlyEdit = suffix == 0;
    final deleteCount = tailOnlyEdit
        ? oldChars.length - prefix
        : _lastSyncedCommittedText.characters.length;
    final insertedText =
        tailOnlyEdit ? newChars.skip(prefix).join() : nextCommittedText;

    for (var index = 0; index < deleteCount; index++) {
      await _sendKeyboard(
        action: 'press',
        arguments: const <String, dynamic>{'key': 'backspace'},
      );
    }

    if (insertedText.isNotEmpty) {
      await _sendKeyboard(
        action: 'type',
        arguments: <String, dynamic>{'text': insertedText},
      );
    }

    _lastSyncedCommittedText = nextCommittedText;
    if (mounted) {
      setState(() {});
    }
  }

  void _toggleLiveImeMode(bool value) {
    setState(() {
      _liveImeMode = value;
      _lastSyncedCommittedText =
          value ? _committedText(_textController.value) : '';
    });
  }

  String _committedText(TextEditingValue value) {
    final composing = value.composing;
    if (!composing.isValid ||
        composing.isCollapsed ||
        composing.start < 0 ||
        composing.end > value.text.length) {
      return value.text;
    }

    return value.text.replaceRange(composing.start, composing.end, '');
  }

  String get _composingPreview {
    final value = _textController.value;
    final composing = value.composing;
    if (!composing.isValid ||
        composing.isCollapsed ||
        composing.start < 0 ||
        composing.end > value.text.length) {
      return '';
    }

    return value.text.substring(composing.start, composing.end);
  }

  Future<void> _showKeyboardPanel({
    required BuildContext context,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.72,
            minChildSize: 0.42,
            maxChildSize: 0.94,
            builder: (
              BuildContext context,
              ScrollController scrollController,
            ) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              Navigator.of(bottomSheetContext).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Close',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(subtitle),
                    const SizedBox(height: 16),
                    child,
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTextInputSection({
    required BuildContext context,
    required bool compact,
  }) {
    return _KeyboardSection(
      title: compact ? 'Composer' : 'Text Input',
      subtitle: compact
          ? 'Keep text entry front and center, then open focused key panels only when you need them.'
          : 'Send text exactly as typed, or enable live IME-aware sync so only committed composition text is sent as it finalizes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _liveImeMode,
            title: const Text('Live IME-aware sync'),
            subtitle: const Text(
              'Committed text syncs automatically while active composition stays local until it is committed.',
            ),
            onChanged: widget.enabled ? _toggleLiveImeMode : null,
          ),
          if (_liveImeMode) ...<Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                Chip(
                  label: Text(
                    _lastSyncedCommittedText.isEmpty
                        ? 'Remote buffer empty'
                        : 'Remote buffer: ${_lastSyncedCommittedText.characters.length} chars',
                  ),
                ),
                if (_composingPreview.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.translate, size: 18),
                    label: Text('Composing: $_composingPreview'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _textController,
            focusNode: _textFocusNode,
            enabled: widget.enabled,
            decoration: const InputDecoration(
              labelText: 'Type text for the remote computer',
              border: OutlineInputBorder(),
            ),
            textInputAction:
                _liveImeMode ? TextInputAction.done : TextInputAction.newline,
            onSubmitted:
                _liveImeMode ? (_) => _commitCurrentComposition() : null,
            minLines: compact ? 2 : 3,
            maxLines: compact ? 4 : 5,
          ),
          const SizedBox(height: 16),
          RemoteButton(
            label: _liveImeMode ? 'Commit Composition' : 'Send Text',
            enabled: widget.enabled,
            onPressed: _submitText,
          ),
        ],
      ),
    );
  }

  Widget _buildModifierSection({
    required BuildContext context,
    required bool compact,
  }) {
    return _KeyboardSection(
      title: compact ? 'Modifiers' : 'Modifier Holds',
      subtitle: compact
          ? 'Keep Ctrl, Alt, Shift, or Win latched while you open the other key panels.'
          : 'Tap a modifier to hold it down on the desktop. Tap again to release it.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _modifiers
                .map(
                  (String key) => FilterChip(
                    label: Text(_displayKeyLabel(key)),
                    selected: _heldModifiers.contains(key),
                    onSelected:
                        widget.enabled ? (_) => _toggleModifier(key) : null,
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              if (_heldModifiers.isNotEmpty)
                Chip(
                  label: Text(
                    'Held: ${_heldModifiers.map(_displayKeyLabel).join(' + ')}',
                  ),
                ),
              OutlinedButton.icon(
                onPressed: widget.enabled && _heldModifiers.isNotEmpty
                    ? _releaseHeldModifiers
                    : null,
                icon: const Icon(Icons.keyboard_hide_outlined),
                label: const Text('Release All'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleKeySection({required bool compact}) {
    return _KeyboardSection(
      title: compact ? 'Named Key' : 'Single Key',
      subtitle: compact
          ? 'Use this when you need a specific key name like F5, Left, or Delete.'
          : 'Send one named key like `F5`, `Enter`, `Left`, `Delete`, or `A`.',
      child: _buildSingleKeyControls(),
    );
  }

  Widget _buildSingleKeyControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _singleKeyController,
          enabled: widget.enabled,
          decoration: const InputDecoration(
            labelText: 'A, F5, Enter, Left...',
            border: OutlineInputBorder(),
          ),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _submitSingleKey(),
        ),
        const SizedBox(height: 16),
        RemoteButton(
          label: 'Send Key',
          enabled: widget.enabled,
          onPressed: _submitSingleKey,
        ),
      ],
    );
  }

  Widget _buildQuickKeysSection() {
    return _KeyboardSection(
      title: 'Quick Keys',
      subtitle:
          'Keep the most-used controls visible so the phone layout stays fast.',
      child: _KeyWrap(
        enabled: widget.enabled,
        keys: _quickKeys,
        onPressed: _pressKey,
      ),
    );
  }

  Widget _buildCompactPanelsSection(BuildContext context) {
    return _KeyboardSection(
      title: 'More Keys',
      subtitle:
          'Open focused popout panels instead of keeping every key group on screen at once.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: <Widget>[
          _PanelLauncherButton(
            label: 'Named Key',
            icon: Icons.keyboard_alt_outlined,
            enabled: widget.enabled,
            onPressed: () => _showKeyboardPanel(
              context: context,
              title: 'Named Key',
              subtitle:
                  'Send a specific named key like F5, Delete, Home, or Left.',
              child: _buildSingleKeyControls(),
            ),
          ),
          _PanelLauncherButton(
            label: 'Edit',
            icon: Icons.edit_note_outlined,
            enabled: widget.enabled,
            onPressed: () => _showKeyboardPanel(
              context: context,
              title: 'Editing Keys',
              subtitle:
                  'Form and terminal controls for escape, tab, enter, backspace, delete, and space.',
              child: _KeyWrap(
                enabled: widget.enabled,
                keys: _editingKeys,
                onPressed: _pressKey,
              ),
            ),
          ),
          _PanelLauncherButton(
            label: 'Navigation',
            icon: Icons.navigation_outlined,
            enabled: widget.enabled,
            onPressed: () => _showKeyboardPanel(
              context: context,
              title: 'Navigation Keys',
              subtitle:
                  'Arrow and paging controls for menus, explorers, and slides.',
              child: _KeyWrap(
                enabled: widget.enabled,
                keys: _navigationKeys,
                onPressed: _pressKey,
              ),
            ),
          ),
          _PanelLauncherButton(
            label: 'Common',
            icon: Icons.key_outlined,
            enabled: widget.enabled,
            onPressed: () => _showKeyboardPanel(
              context: context,
              title: 'Common Combo Keys',
              subtitle:
                  'Convenient letters and digits for Ctrl combos and quick numeric entry.',
              child: _KeyWrap(
                enabled: widget.enabled,
                keys: _commonKeys,
                onPressed: _pressKey,
              ),
            ),
          ),
          _PanelLauncherButton(
            label: 'Function',
            icon: Icons.piano_outlined,
            enabled: widget.enabled,
            onPressed: () => _showKeyboardPanel(
              context: context,
              title: 'Function Keys',
              subtitle: 'F1 through F12 as one-tap key presses.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List<Widget>.generate(
                  12,
                  (int index) {
                    final key = 'f${index + 1}';
                    return _KeyButton(
                      label: key.toUpperCase(),
                      enabled: widget.enabled,
                      onPressed: () => _pressKey(key),
                    );
                  },
                ),
              ),
            ),
          ),
          _PanelLauncherButton(
            label: 'Shortcuts',
            icon: Icons.auto_awesome_motion_outlined,
            enabled: widget.enabled,
            onPressed: () => _showKeyboardPanel(
              context: context,
              title: 'Shortcuts',
              subtitle: 'One-shot combos that do not depend on held modifiers.',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _shortcuts
                    .map(
                      (_ShortcutPreset shortcut) => FilledButton.tonal(
                        onPressed: widget.enabled
                            ? () => _sendShortcut(shortcut.keys)
                            : null,
                        child: Text(shortcut.label),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterNote(BuildContext context) {
    return Text(
      _liveImeMode
          ? 'Live IME mode syncs committed edits and keeps pre-edit composition local until commit. Clipboard sync is still not implemented.'
          : 'Clipboard sync is still not implemented. This keyboard now supports compact staged popouts, individual keys, held modifiers, and common Windows shortcuts.',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  List<Widget> _buildCompactChildren(BuildContext context) {
    return <Widget>[
      _buildTextInputSection(context: context, compact: true),
      const SizedBox(height: 20),
      _buildModifierSection(context: context, compact: true),
      const SizedBox(height: 20),
      _buildQuickKeysSection(),
      const SizedBox(height: 20),
      _buildCompactPanelsSection(context),
      const SizedBox(height: 12),
      _buildFooterNote(context),
    ];
  }

  List<Widget> _buildExpandedChildren(BuildContext context) {
    return <Widget>[
      _buildTextInputSection(context: context, compact: false),
      const SizedBox(height: 20),
      _buildModifierSection(context: context, compact: false),
      const SizedBox(height: 20),
      _buildSingleKeySection(compact: false),
      const SizedBox(height: 20),
      _KeyboardSection(
        title: 'Editing Keys',
        subtitle: 'Common control keys for forms, terminals, and dialogs.',
        child: _KeyWrap(
          enabled: widget.enabled,
          keys: _editingKeys,
          onPressed: _pressKey,
        ),
      ),
      const SizedBox(height: 20),
      _KeyboardSection(
        title: 'Navigation',
        subtitle: 'Arrow and navigation keys for menus, explorers, and slides.',
        child: _KeyWrap(
          enabled: widget.enabled,
          keys: _navigationKeys,
          onPressed: _pressKey,
        ),
      ),
      const SizedBox(height: 20),
      _KeyboardSection(
        title: 'Common Keys',
        subtitle:
            'Useful for modifier combos like Ctrl+C, Ctrl+V, Ctrl+Z, and quick numeric input.',
        child: _KeyWrap(
          enabled: widget.enabled,
          keys: _commonKeys,
          onPressed: _pressKey,
        ),
      ),
      const SizedBox(height: 20),
      _KeyboardSection(
        title: 'Function Keys',
        subtitle: 'F1 through F12 as one-tap key presses.',
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: List<Widget>.generate(
            12,
            (int index) {
              final key = 'f${index + 1}';
              return _KeyButton(
                label: key.toUpperCase(),
                enabled: widget.enabled,
                onPressed: () => _pressKey(key),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 20),
      _KeyboardSection(
        title: 'Shortcuts',
        subtitle: 'One-shot combos that do not depend on held modifiers.',
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _shortcuts
              .map(
                (_ShortcutPreset shortcut) => FilledButton.tonal(
                  onPressed: widget.enabled
                      ? () => _sendShortcut(shortcut.keys)
                      : null,
                  child: Text(shortcut.label),
                ),
              )
              .toList(growable: false),
        ),
      ),
      const SizedBox(height: 12),
      _buildFooterNote(context),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: compact
              ? _buildCompactChildren(context)
              : _buildExpandedChildren(context),
        );
      },
    );
  }
}

class _KeyboardSection extends StatelessWidget {
  const _KeyboardSection({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _KeyWrap extends StatelessWidget {
  const _KeyWrap({
    required this.enabled,
    required this.keys,
    required this.onPressed,
  });

  final bool enabled;
  final List<_KeyPreset> keys;
  final Future<void> Function(String key) onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: keys
          .map(
            (_KeyPreset preset) => _KeyButton(
              label: preset.label,
              enabled: enabled,
              onPressed: () => onPressed(preset.key),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        onPressed: enabled ? onPressed : null,
        child: Text(label),
      ),
    );
  }
}

class _PanelLauncherButton extends StatelessWidget {
  const _PanelLauncherButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _KeyPreset {
  const _KeyPreset(this.label, this.key);

  final String label;
  final String key;
}

class _ShortcutPreset {
  const _ShortcutPreset(this.label, this.keys);

  final String label;
  final List<String> keys;
}

String _displayKeyLabel(String key) {
  switch (key) {
    case 'ctrl':
      return 'Ctrl';
    case 'alt':
      return 'Alt';
    case 'shift':
      return 'Shift';
    case 'win':
      return 'Win';
    default:
      return key.toUpperCase();
  }
}
