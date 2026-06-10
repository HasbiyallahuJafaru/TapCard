/// Colour palette for the TapCard design system.
/// All colour constants live here. Never define colours inline in widget code.
/// See .claude/UI_DIRECTION.md for the 60/30/10 usage rule.
library;

import 'package:flutter/painting.dart';

/// The complete TapCard colour palette.
///
/// Usage rule (60/30/10):
/// - 60 % → [bgPrimary] / [bgSecondary] — dominant surfaces
/// - 30 % → [bgTertiary] / typography at 60 % opacity
/// - 10 % → [accent], functional colours, NFC state indicators
abstract final class AppColours {
  AppColours._();

  // ─── Backgrounds ────────────────────────────────────────────────────────────

  /// Near-black warm-neutral — dominant background for every screen
  static const Color bgPrimary = Color(0xFF0E0E0E);

  /// Slightly lighter card surface
  static const Color bgSecondary = Color(0xFF161616);

  /// Elevated surface — input fills, tertiary cards
  static const Color bgTertiary = Color(0xFF1F1F1F);

  // ─── Text ───────────────────────────────────────────────────────────────────

  /// Warm off-white — primary readable text (not pure white)
  static const Color textPrimary = Color(0xFFF2F0EC);

  /// 60 % muted warm grey — secondary descriptive text
  static const Color textSecondary = Color(0xFF9E9B96);

  /// 35 % captions and placeholders
  static const Color textTertiary = Color(0xFF5C5A57);

  /// 20 % inactive / disabled text
  static const Color textDisabled = Color(0xFF333230);

  // ─── Accent ─────────────────────────────────────────────────────────────────

  /// Warm parchment — single accent colour, used sparingly (≤10 % of screen)
  static const Color accent = Color(0xFFE8E0D4);

  /// Accent at surface level — muted version for backgrounds
  static const Color accentMuted = Color(0xFF3D3A36);

  // ─── Functional ─────────────────────────────────────────────────────────────

  /// Standard green — success states (not lime)
  static const Color success = Color(0xFF4CAF50);

  /// Muted red — error states (not bright)
  static const Color error = Color(0xFFE57373);

  /// Barely-visible divider line
  static const Color divider = Color(0xFF232320);

  // ─── NFC state colours ───────────────────────────────────────────────────────

  /// Dormant NFC ring — idle state
  static const Color nfcIdle = Color(0xFF2A2A2A);

  /// Active NFC ring — armed state (same as [textPrimary], intentional)
  static const Color nfcArmed = Color(0xFFF2F0EC);

  /// Tap confirmed — success flash on the NFC circle
  static const Color nfcSuccess = Color(0xFF4CAF50);
}
