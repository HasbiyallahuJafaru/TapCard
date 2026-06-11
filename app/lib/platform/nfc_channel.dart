/// Typed Dart wrapper for the tapcard/nfc platform channel.
///
/// All NFC HCE arming, disarming, and state queries must go through [NfcChannel].
/// The raw [MethodChannel] is private — no feature code may call it directly.
/// See .claude/PLATFORM_CHANNEL.md for the full frozen contract.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ---------------------------------------------------------------------------
// Value types
// ---------------------------------------------------------------------------

/// NFC hardware and software availability state.
///
/// [available] — true if the device has NFC hardware.
/// [enabled]   — true if NFC is currently on in system settings.
///               Meaningless when [available] is false.
class NfcAvailability {
  const NfcAvailability({required this.available, required this.enabled});

  final bool available;
  final bool enabled;

  @override
  String toString() => 'NfcAvailability(available: $available, enabled: $enabled)';
}

/// Current HCE arm state.
///
/// [armed]        — true if the service is armed and the window has not expired.
/// [remainingSec] — seconds until expiry; 0 if disarmed or expired.
class ArmState {
  const ArmState({required this.armed, required this.remainingSec});

  final bool armed;
  final int remainingSec;

  @override
  String toString() => 'ArmState(armed: $armed, remainingSec: $remainingSec)';
}

// ---------------------------------------------------------------------------
// Error types
// ---------------------------------------------------------------------------

/// Error codes returned by the tapcard/nfc channel.
/// Values mirror the PlatformException codes in NfcPlugin.kt.
enum NfcErrorCode {
  invalidUrl,
  payloadTooLong,
  noPayload,
  nfcUnavailable,
  nfcDisabled,
  unknown,
}

/// Typed exception wrapping a [PlatformException] from the NFC channel.
///
/// [code]    — the specific error category.
/// [message] — human-readable description for logging only (English).
class TapCardNfcException implements Exception {
  const TapCardNfcException({required this.code, required this.message});

  final NfcErrorCode code;
  final String message;

  @override
  String toString() => 'TapCardNfcException(code: $code, message: $message)';
}

// ---------------------------------------------------------------------------
// Channel
// ---------------------------------------------------------------------------

/// Callback signature for when Kotlin confirms an NFC tap success.
typedef TapSuccessCallback = void Function();

/// Typed wrapper for the `tapcard/nfc` platform channel.
///
/// All methods catch [PlatformException] and convert it to [TapCardNfcException]
/// with a [NfcErrorCode] enum. Raw [PlatformException] never leaks into feature code.
class NfcChannel {
  static const _channel = MethodChannel('tapcard/nfc');

  /// CHANNEL_VERSION must match NfcPlugin.kt companion object value.
  // ignore: unused_field
  static const int channelVersion = 1;

  /// Returns the current NFC hardware and enabled state.
  ///
  /// Never throws — returns [NfcAvailability(available: false, enabled: false)]
  /// on any hardware query failure.
  Future<NfcAvailability> isNfcAvailable() async {
    try {
      final result = await _channel.invokeMethod<Map>('isNfcAvailable');
      return NfcAvailability(
        available: (result?['available'] as bool?) ?? false,
        enabled:   (result?['enabled']   as bool?) ?? false,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[NfcChannel] isNfcAvailable error: ${e.code}');
      return const NfcAvailability(available: false, enabled: false);
    }
  }

  /// Stores the vCard payload for HCE. Must be called before [arm].
  ///
  /// [vCard] — raw vCard 3.0 string from [VCardBuilder.build].
  /// Throws [TapCardNfcException] on validation failure.
  Future<void> setPayload(String vCard) async {
    try {
      await _channel.invokeMethod<bool>('setPayload', {'vcard': vCard});
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[NfcChannel] setPayload error: ${e.code}');
      throw TapCardNfcException(code: _mapCode(e.code), message: e.message ?? '');
    }
  }

  /// Arms the HCE service for [timeoutSec] seconds (default 60, clamped 10–300).
  ///
  /// Throws [TapCardNfcException] with [NfcErrorCode.noPayload] if [setPayload]
  /// has not been called, or with [NfcErrorCode.nfcUnavailable] /
  /// [NfcErrorCode.nfcDisabled] based on device state.
  Future<void> arm({int timeoutSec = 60}) async {
    try {
      await _channel.invokeMethod<bool>('arm', {'timeoutSec': timeoutSec});
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[NfcChannel] arm error: ${e.code}');
      throw TapCardNfcException(code: _mapCode(e.code), message: e.message ?? '');
    }
  }

  /// Disarms the HCE service immediately.
  ///
  /// Idempotent — safe to call when already disarmed. Never throws.
  Future<void> disarm() async {
    try {
      await _channel.invokeMethod<void>('disarm');
    } on PlatformException catch (e) {
      // disarm is fire-and-forget; log and swallow
      if (kDebugMode) debugPrint('[NfcChannel] disarm error (non-fatal): ${e.code}');
    }
  }

  /// Returns the current arm state and seconds remaining until expiry.
  ///
  /// Returns [ArmState(armed: false, remainingSec: 0)] on any channel error.
  Future<ArmState> getArmState() async {
    try {
      final result = await _channel.invokeMethod<Map>('getArmState');
      return ArmState(
        armed:        (result?['armed']        as bool?) ?? false,
        remainingSec: (result?['remainingSec'] as int?)  ?? 0,
      );
    } on PlatformException catch (e) {
      if (kDebugMode) debugPrint('[NfcChannel] getArmState error: ${e.code}');
      return const ArmState(armed: false, remainingSec: 0);
    }
  }

  /// Registers a handler for [onTapSuccess] calls from Kotlin.
  ///
  /// Kotlin's MainActivity fires this when [NdefHostApduService] confirms the
  /// NDEF body was fully served to the reader. Call this once during app startup.
  void setTapSuccessHandler(TapSuccessCallback onSuccess) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTapSuccess') {
        if (kDebugMode) debugPrint('[NfcChannel] ← onTapSuccess');
        onSuccess();
      } else {
        throw MissingPluginException('Unknown nfc channel method: ${call.method}');
      }
    });
  }

  /// Maps a raw PlatformException error code string to a typed [NfcErrorCode].
  NfcErrorCode _mapCode(String code) {
    return switch (code) {
      'INVALID_URL'     => NfcErrorCode.invalidUrl,
      'PAYLOAD_TOO_LONG'=> NfcErrorCode.payloadTooLong,
      'NO_PAYLOAD'      => NfcErrorCode.noPayload,
      'NFC_UNAVAILABLE' => NfcErrorCode.nfcUnavailable,
      'NFC_DISABLED'    => NfcErrorCode.nfcDisabled,
      _                 => NfcErrorCode.unknown,
    };
  }
}
