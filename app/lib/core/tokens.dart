/// Design token constants for TapCard.
/// Single source of truth for all spacing, radius, and duration values.
/// Never use magic numbers in layout code — always reference AppTokens.
library;

import 'package:flutter/animation.dart';

/// Spacing, radius, and animation duration tokens for the TapCard design system.
///
/// All layout measurements in the app must reference these values.
/// Adding new tokens here is fine; bypassing them is not.
abstract final class AppTokens {
  AppTokens._();

  // ─── Spacing ────────────────────────────────────────────────────────────────

  /// 4 dp — tight internal padding, icon gaps
  static const double xs = 4;

  /// 8 dp — small gaps between related elements
  static const double sm = 8;

  /// 16 dp — standard card padding, field gaps
  static const double md = 16;

  /// 24 dp — screen horizontal padding, section internal spacing
  static const double lg = 24;

  /// 32 dp — between major sections
  static const double xl = 32;

  /// 48 dp — bottom padding above nav/buttons (minimum)
  static const double xxl = 48;

  // ─── Border radius ──────────────────────────────────────────────────────────

  /// 8 dp — small chips, tags
  static const double radiusSm = 8;

  /// 16 dp — input fields, cards
  static const double radiusMd = 16;

  /// 24 dp — bottom sheets (top corners), large surfaces
  static const double radiusLg = 24;

  /// 999 dp — fully round (pill buttons, avatar circles)
  static const double radiusFull = 999;

  // ─── Touch targets ──────────────────────────────────────────────────────────

  /// 48 dp — minimum touch target dimension (system accessibility requirement)
  static const double minTouchTarget = 48;

  // ─── Animation durations ────────────────────────────────────────────────────

  /// 120 ms — immediate tap feedback
  static const Duration tapFeedback = Duration(milliseconds: 120);

  /// 280 ms — state changes (text cross-fade, button colour)
  static const Duration stateChange = Duration(milliseconds: 280);

  /// 420 ms — screen entrance animations
  static const Duration entrance = Duration(milliseconds: 420);

  /// 600 ms — NFC arm/disarm ring expansion
  static const Duration nfcArm = Duration(milliseconds: 600);

  // ─── Animation curves ───────────────────────────────────────────────────────

  /// Snappy UI responses (button press, dismiss)
  static const Curve snap = Curves.easeOutCubic;

  /// Smooth state transitions
  static const Curve settle = Curves.easeInOutCubic;

  /// Elastic spring — arm/disarm ring
  static const Curve spring = Curves.elasticOut;

  /// Screen entrances
  static const Curve entrance_ = Curves.easeOutQuart;

  // ─── NFC share screen geometry ───────────────────────────────────────────────

  /// Idle radius of the NFC tap-zone circle (dp)
  static const double nfcCircleIdle = 80;

  /// Armed radius of the NFC tap-zone circle (dp)
  static const double nfcCircleArmed = 120;
}
