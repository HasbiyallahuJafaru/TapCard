/// CustomPainter that draws the NFC tap-zone ring on the share screen.
/// Renders an arc that drains clockwise as the countdown progresses,
/// plus a faint background ring so the drain is visible at low progress.
library;

import 'dart:math' as math;
import 'package:flutter/rendering.dart';

import '../../core/colours.dart';

/// Draws the NFC arm ring — a circular arc that represents countdown progress.
///
/// [progress] 1.0 = full ring (just armed), 0.0 = empty ring (timeout).
/// [ringColor] is the foreground arc colour; background ring is always [AppColours.nfcIdle].
/// [strokeWidth] controls the ring thickness.
///
/// Usage:
/// ```dart
/// CustomPaint(
///   size: const Size(240, 240),
///   painter: NfcRingPainter(progress: 0.75, ringColor: AppColours.nfcArmed),
/// )
/// ```
class NfcRingPainter extends CustomPainter {
  const NfcRingPainter({
    required this.progress,
    required this.ringColor,
    this.strokeWidth = 3.0,
  });

  /// Countdown progress from 1.0 (full) to 0.0 (empty). Clamped internally.
  final double progress;

  /// Colour of the foreground arc (the part still remaining).
  final Color ringColor;

  /// Thickness of both the background and foreground ring strokes.
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // Leave room so the stroke doesn't clip at the edge.
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw the background ring (always the full circle, faint).
    final bgPaint = Paint()
      ..color = AppColours.nfcIdle
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Draw the foreground arc only when there is remaining progress.
    final clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress <= 0.0) return;

    final fgPaint = Paint()
      ..color = ringColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Arc starts at 12 o'clock (-π/2) and sweeps clockwise.
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * clampedProgress;

    canvas.drawArc(rect, startAngle, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(NfcRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.ringColor != ringColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
