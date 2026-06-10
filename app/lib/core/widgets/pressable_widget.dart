/// PressableWidget — the only allowed tap wrapper in the TapCard design system.
/// Replaces raw GestureDetector / InkWell on any visible interactive element.
/// Provides scale-down press feedback matching the motion spec in UI_DIRECTION.md.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// A tappable container that scales down slightly on press and springs back on release.
///
/// Usage: wrap any tappable widget with [PressableWidget] instead of using
/// [GestureDetector] or [InkWell] directly. Every interactive element in the
/// app must use this widget — raw gesture detectors are banned by CODE_STANDARDS.md.
///
/// The scale animation matches the motion spec:
///   - Press:   scale 1.0 → 0.97, [AppTokens.tapFeedback] (120 ms), [AppTokens.snap]
///   - Release: scale 0.97 → 1.0, [AppTokens.tapFeedback] (120 ms), [AppTokens.snap]
///
/// [onTap] — required callback, called on tap-up (after animation).
/// [onLongPress] — optional long-press callback.
/// [enabled] — when false, the widget is non-interactive and does not animate.
/// [child] — the widget to make pressable.
class PressableWidget extends StatefulWidget {
  const PressableWidget({
    super.key,
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.enabled = true,
  });

  final VoidCallback onTap;
  final Widget child;
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  State<PressableWidget> createState() => _PressableWidgetState();
}

class _PressableWidgetState extends State<PressableWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppTokens.tapFeedback,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AppTokens.snap),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _controller.reverse();
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
