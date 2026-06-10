/// Typography system for TapCard.
/// Font pairing: Syne (display/headings) · DM Sans (body/UI) · DM Mono (data).
/// All text styles must come from this class — never construct TextStyle inline.
/// See .claude/UI_DIRECTION.md §Typography for the full usage map.
library;

import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colours.dart';

/// Factory for all text styles used in the TapCard app.
///
/// Every public method returns a [TextStyle] configured for a specific
/// typographic role. Pass [color] to override the default; all other
/// parameters (weight, tracking, leading) are fixed per role to maintain
/// visual consistency.
abstract final class AppTypography {
  AppTypography._();

  // ─── Display — Syne 700 ─────────────────────────────────────────────────────

  /// Hero / app-name text. Syne 700, tight tracking.
  ///
  /// [size] — typically 36–44 sp (see UI_DIRECTION.md usage map)
  /// [color] — defaults to [AppColours.textPrimary]
  /// [letterSpacing] — defaults to −0.03 × size (tight); override sparingly
  static TextStyle display({
    required double size,
    Color? color,
    double? letterSpacing,
  }) =>
      GoogleFonts.syne(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color ?? AppColours.textPrimary,
        letterSpacing: letterSpacing ?? -0.03 * size,
        height: 1.1,
      );

  // ─── Title — Syne 600 ────────────────────────────────────────────────────────

  /// Screen titles and section headers. Syne 600.
  ///
  /// [size] — 18–28 sp depending on hierarchy level
  /// [color] — defaults to [AppColours.textPrimary]
  static TextStyle title({required double size, Color? color}) =>
      GoogleFonts.syne(
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: color ?? AppColours.textPrimary,
        letterSpacing: -0.02 * size,
        height: 1.2,
      );

  // ─── Body — DM Sans 400 ──────────────────────────────────────────────────────

  /// Descriptive / explanatory body copy. DM Sans 400.
  ///
  /// [size] — 13–15 sp
  /// [color] — defaults to [AppColours.textSecondary] (muted)
  static TextStyle body({required double size, Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? AppColours.textSecondary,
        letterSpacing: 0.01 * size,
        height: 1.55,
      );

  // ─── Body Medium — DM Sans 500 ───────────────────────────────────────────────

  /// Primary list/card text. DM Sans 500.
  ///
  /// [size] — 15–17 sp
  /// [color] — defaults to [AppColours.textPrimary]
  static TextStyle bodyMedium({required double size, Color? color}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? AppColours.textPrimary,
        letterSpacing: 0,
        height: 1.4,
      );

  // ─── Label — DM Sans 500 uppercase ───────────────────────────────────────────

  /// Overlines, captions, field labels. DM Sans 500.
  ///
  /// [size] — 10–11 sp
  /// [color] — defaults to [AppColours.textTertiary]
  /// [uppercase] — true by default; sets wide letter-spacing for all-caps look
  static TextStyle label({
    required double size,
    Color? color,
    bool uppercase = true,
  }) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color ?? AppColours.textTertiary,
        letterSpacing: uppercase ? 0.12 * size : 0.02 * size,
        height: 1.2,
        textBaseline: TextBaseline.alphabetic,
      );

  // ─── Mono — DM Mono 400 ──────────────────────────────────────────────────────

  /// Phone numbers, countdown timer, data codes. DM Mono 400.
  ///
  /// [size] — 17 sp for phone numbers, 32 sp for countdown
  /// [color] — defaults to [AppColours.textPrimary]
  static TextStyle mono({required double size, Color? color}) =>
      GoogleFonts.dmMono(
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color ?? AppColours.textPrimary,
        letterSpacing: 0,
        height: 1.4,
      );
}
