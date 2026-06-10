/// Encodes and decodes the vCard payload for use in a share URL fragment.
/// Uses base64url (RFC 4648 §5 — URL-safe alphabet, no padding).
/// This file is NOT responsible for building the vCard string — see vcard_builder.dart.
library;

import 'dart:convert';
import '../core/constants.dart';

/// Result of a [UrlCodec.encode] call, indicating success or length overflow.
sealed class EncodeResult {
  const EncodeResult();
}

/// Successful encoding — [url] is ready to use as the NDEF payload.
final class EncodeSuccess extends EncodeResult {
  /// The full share URL including the base64url fragment.
  final String url;

  /// Length of [url] in characters.
  final int length;

  const EncodeSuccess({required this.url, required this.length});
}

/// The encoded URL would exceed [AppConstants.maxUrlLength].
///
/// [actualLength] is the length the URL would have been.
/// The caller should truncate optional vCard fields and retry.
final class EncodeTooLong extends EncodeResult {
  /// How many characters the URL would have been.
  final int actualLength;

  const EncodeTooLong({required this.actualLength});
}

/// Encodes and decodes vCard payloads for TapCard share URLs.
///
/// URL format: `https://<domain>/#<base64url_vcard>`
///
/// Encoding uses base64url with no padding (RFC 4648 §5). The fragment
/// (`#...`) is decoded entirely in the browser — it never reaches the server.
abstract final class UrlCodec {
  UrlCodec._();

  /// Encodes [vCardString] into a full share URL.
  ///
  /// Returns [EncodeSuccess] if the resulting URL is within the
  /// [AppConstants.maxUrlLength] limit, or [EncodeTooLong] if it exceeds it.
  ///
  /// [vCardString] — UTF-8 vCard 3.0 string from [VCardBuilder.build].
  ///
  /// Throws [ArgumentError] if [vCardString] is empty.
  static EncodeResult encode(String vCardString) {
    if (vCardString.isEmpty) {
      throw ArgumentError.value(vCardString, 'vCardString', 'must not be empty');
    }

    final encoded = _base64UrlEncode(vCardString);
    final url = '${AppConstants.decoderBaseUrl}/#$encoded';
    final length = url.length;

    if (length > AppConstants.maxUrlLength) {
      return EncodeTooLong(actualLength: length);
    }

    return EncodeSuccess(url: url, length: length);
  }

  /// Decodes a base64url fragment back to the original vCard string.
  ///
  /// [fragment] — the raw fragment value from the URL (everything after `#`).
  ///
  /// Returns the decoded UTF-8 string, or throws [FormatException] if the
  /// fragment is not valid base64url.
  ///
  /// Throws [ArgumentError] if [fragment] is empty.
  static String decode(String fragment) {
    if (fragment.isEmpty) {
      throw ArgumentError.value(fragment, 'fragment', 'must not be empty');
    }

    return _base64UrlDecode(fragment);
  }

  /// Returns the character length that a share URL for [vCardString] would have,
  /// without performing the full length guard check.
  ///
  /// Useful for the card editor's live character counter.
  static int computeUrlLength(String vCardString) {
    if (vCardString.isEmpty) return 0;
    final encoded = _base64UrlEncode(vCardString);
    return '${AppConstants.decoderBaseUrl}/#$encoded'.length;
  }

  // ─── Internal helpers ────────────────────────────────────────────────────────

  /// Encodes [input] to base64url with no padding (RFC 4648 §5).
  ///
  /// No padding is important: the `=` padding character is technically
  /// allowed in URL fragments but creates visual noise and may be
  /// percent-encoded by some URL parsers.
  static String _base64UrlEncode(String input) {
    final bytes = utf8.encode(input);
    // base64Url uses `-` and `_` instead of `+` and `/`, and we strip `=` padding.
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decodes a base64url string (with or without padding) back to UTF-8.
  static String _base64UrlDecode(String input) {
    // Re-add padding if stripped — base64 requires length to be a multiple of 4.
    final padded = _addBase64Padding(input);
    final bytes = base64Url.decode(padded);
    return utf8.decode(bytes);
  }

  /// Adds `=` padding to a base64url string until its length is a multiple of 4.
  static String _addBase64Padding(String input) {
    final remainder = input.length % 4;
    if (remainder == 0) return input;
    return input.padRight(input.length + (4 - remainder), '=');
  }
}
