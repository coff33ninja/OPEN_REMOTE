import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class TouchpadSurface extends StatefulWidget {
  const TouchpadSurface({
    super.key,
    required this.enabled,
    required this.label,
    required this.sensitivity,
    required this.onMove,
    required this.onTap,
    required this.onSecondaryTap,
    required this.onDoubleTap,
    required this.onScroll,
    required this.onButtonDown,
    required this.onButtonUp,
    this.showScrollRail = true,
    this.showHints = true,
    this.allowTapClick = true,
    this.enableHoldDrag = true,
  });

  final bool enabled;
  final String label;
  final double sensitivity;
  final Future<void> Function(Offset delta) onMove;
  final Future<void> Function() onTap;
  final Future<void> Function() onSecondaryTap;
  final Future<void> Function() onDoubleTap;
  final Future<void> Function(int verticalSteps) onScroll;
  final Future<void> Function(String button) onButtonDown;
  final Future<void> Function(String button) onButtonUp;
  final bool showScrollRail;
  final bool showHints;
  final bool allowTapClick;
  final bool enableHoldDrag;

  @override
  State<TouchpadSurface> createState() => _TouchpadSurfaceState();
}

class _TouchpadSurfaceState extends State<TouchpadSurface> {
  static const double _scrollThreshold = 18;
  static const double _tapMoveThreshold = 10;

  final Set<int> _activePointers = <int>{};
  bool _holdDragging = false;
  bool _tapGestureMoved = false;
  int _maxPointersInGesture = 0;
  Offset _lastHoldOffset = Offset.zero;
  double _scrollAccumulator = 0;
  Timer? _skipPrimaryTapTimer;
  bool _skipNextPrimaryTap = false;

  @override
  void dispose() {
    _skipPrimaryTapTimer?.cancel();
    super.dispose();
  }

  void _sendMove(Offset delta) {
    final adjusted = Offset(
      delta.dx * widget.sensitivity,
      delta.dy * widget.sensitivity,
    );
    final dx = adjusted.dx.round();
    final dy = adjusted.dy.round();
    if (dx == 0 && dy == 0) {
      return;
    }

    unawaited(widget.onMove(Offset(dx.toDouble(), dy.toDouble())));
  }

  void _handleScroll(double deltaY) {
    _scrollAccumulator += deltaY;
    while (_scrollAccumulator.abs() >= _scrollThreshold) {
      final verticalStep = _scrollAccumulator.isNegative ? 1 : -1;
      unawaited(widget.onScroll(verticalStep));
      _scrollAccumulator +=
          verticalStep > 0 ? _scrollThreshold : -_scrollThreshold;
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    _maxPointersInGesture =
        math.max(_maxPointersInGesture, _activePointers.length);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (event.delta.distance > _tapMoveThreshold / 4) {
      _tapGestureMoved = true;
    }
  }

  void _handlePointerUp(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isNotEmpty) {
      return;
    }

    final shouldTriggerSecondaryTap = widget.enabled &&
        widget.allowTapClick &&
        !_holdDragging &&
        !_tapGestureMoved &&
        _maxPointersInGesture == 2;
    _resetPointerTracking();

    if (!shouldTriggerSecondaryTap) {
      return;
    }

    _skipNextPrimaryTap = true;
    _skipPrimaryTapTimer?.cancel();
    _skipPrimaryTapTimer = Timer(const Duration(milliseconds: 180), () {
      _skipNextPrimaryTap = false;
    });
    unawaited(widget.onSecondaryTap());
  }

  void _resetPointerTracking() {
    _tapGestureMoved = false;
    _maxPointersInGesture = 0;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Listener(
            onPointerDown: _handlePointerDown,
            onPointerMove: _handlePointerMove,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerUp,
            child: GestureDetector(
              onTap: widget.enabled && widget.allowTapClick
                  ? () {
                      if (_skipNextPrimaryTap) {
                        _skipNextPrimaryTap = false;
                        _skipPrimaryTapTimer?.cancel();
                        return;
                      }
                      unawaited(widget.onTap());
                    }
                  : null,
              onDoubleTap: widget.enabled && widget.allowTapClick
                  ? () => unawaited(widget.onDoubleTap())
                  : null,
              onPanUpdate: widget.enabled
                  ? (DragUpdateDetails details) {
                      if (_holdDragging) {
                        return;
                      }
                      _sendMove(details.delta);
                    }
                  : null,
              onLongPressStart: widget.enabled && widget.enableHoldDrag
                  ? (_) {
                      setState(() {
                        _holdDragging = true;
                        _lastHoldOffset = Offset.zero;
                      });
                      unawaited(widget.onButtonDown('left'));
                    }
                  : null,
              onLongPressMoveUpdate: widget.enabled && widget.enableHoldDrag
                  ? (LongPressMoveUpdateDetails details) {
                      final delta = details.offsetFromOrigin - _lastHoldOffset;
                      _lastHoldOffset = details.offsetFromOrigin;
                      _sendMove(delta);
                    }
                  : null,
              onLongPressEnd: widget.enabled && widget.enableHoldDrag
                  ? (_) {
                      setState(() {
                        _holdDragging = false;
                        _lastHoldOffset = Offset.zero;
                      });
                      unawaited(widget.onButtonUp('left'));
                    }
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.enabled
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF364152),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _holdDragging ? 'Dragging' : widget.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.showHints) ...<Widget>[
                          const SizedBox(height: 10),
                          const Text(
                            'One finger tap: left click. Two finger tap: right click. Hold to drag.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.showScrollRail) ...<Widget>[
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: GestureDetector(
              onVerticalDragUpdate: widget.enabled
                  ? (DragUpdateDetails details) {
                      _handleScroll(details.delta.dy);
                    }
                  : null,
              onVerticalDragEnd: widget.enabled
                  ? (_) {
                      _scrollAccumulator = 0;
                    }
                  : null,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0ECE4),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFD0C3B4)),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final compact = constraints.maxHeight < 148;
                    return Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: compact ? 10 : 18,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.keyboard_arrow_up,
                              size: compact ? 20 : 24,
                            ),
                            if (!compact)
                              const RotatedBox(
                                quarterTurns: 1,
                                child: Text(
                                  'Scroll',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: compact ? 20 : 24,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
