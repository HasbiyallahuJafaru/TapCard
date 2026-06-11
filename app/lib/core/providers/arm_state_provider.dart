/// Riverpod state notifier for the NFC arm/disarm/countdown lifecycle.
/// This is the single source of truth for the share screen's runtime state.
/// Feature code reads [armStateProvider] and calls [ArmStateNotifier] methods.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants.dart';
import 'nfc_channel_provider.dart';
import '../../platform/nfc_channel.dart';

// ---------------------------------------------------------------------------
// State data
// ---------------------------------------------------------------------------

/// The three phases of the share screen's NFC lifecycle.
enum TapSharePhase {
  /// NFC is off. The tap zone is in its default resting state.
  idle,

  /// NFC is armed and counting down. The ring is expanded and draining.
  armed,

  /// A successful tap was confirmed. The checkmark is shown briefly.
  success,
}

/// Immutable snapshot of the current arm state.
class ArmStateData {
  /// Creates an [ArmStateData].
  ///
  /// [phase] defaults to [TapSharePhase.idle], [remainingSec] to 0.
  const ArmStateData({
    this.phase = TapSharePhase.idle,
    this.remainingSec = 0,
    this.errorMessage,
  });

  /// Current lifecycle phase.
  final TapSharePhase phase;

  /// Seconds remaining in the arm window. Only meaningful when [phase] is [TapSharePhase.armed].
  final int remainingSec;

  /// Non-null when an arm attempt failed. Cleared on the next arm attempt.
  final String? errorMessage;

  /// Returns a copy with specific fields replaced.
  ArmStateData copyWith({
    TapSharePhase? phase,
    int? remainingSec,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ArmStateData(
      phase: phase ?? this.phase,
      remainingSec: remainingSec ?? this.remainingSec,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  String toString() =>
      'ArmStateData(phase: $phase, remainingSec: $remainingSec, error: $errorMessage)';
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages the NFC arm/disarm lifecycle and exposes it as a [StateNotifier].
///
/// Call [arm] with the pre-built share URL to arm the HCE service.
/// Call [disarm] to manually cancel. The countdown runs internally via a [Timer]
/// and auto-disarms when it reaches zero.
///
/// Success detection (Phase 3): the success state is exposed via [triggerSuccess]
/// for testing. Phase 4 will wire a Kotlin → Flutter callback that calls this
/// when the NDEF read is confirmed by the remote device.
class ArmStateNotifier extends StateNotifier<ArmStateData> {
  /// Creates an [ArmStateNotifier] with Riverpod [Ref] for reading sibling providers.
  ArmStateNotifier(this._ref) : super(const ArmStateData());

  final Ref _ref;
  Timer? _countdownTimer;
  Timer? _successResetTimer;

  NfcChannel get _nfc => _ref.read(nfcChannelProvider);

  // ─── Public API ─────────────────────────────────────────────────────────────

  /// Sets the vCard payload and arms the HCE service.
  ///
  /// [vCard] — raw vCard 3.0 string from [VCardBuilder.build].
  ///
  /// Updates state to [TapSharePhase.armed] on success, or writes
  /// [ArmStateData.errorMessage] on failure without changing [phase].
  Future<void> arm(String vCard) async {
    _cancelTimers();
    state = state.copyWith(clearError: true);

    try {
      await _nfc.setPayload(vCard);
      await _nfc.arm(timeoutSec: AppConstants.armTimeoutSec);

      state = ArmStateData(
        phase: TapSharePhase.armed,
        remainingSec: AppConstants.armTimeoutSec,
      );

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
    } on TapCardNfcException catch (e) {
      if (kDebugMode) debugPrint('[ArmStateNotifier] arm failed: ${e.code}');
      state = state.copyWith(
        errorMessage: _userMessageForError(e.code),
      );
    }
  }

  /// Disarms the HCE service and resets to idle.
  ///
  /// Idempotent — safe to call when already idle.
  Future<void> disarm() async {
    _cancelTimers();
    await _nfc.disarm();
    state = const ArmStateData();
  }

  /// Syncs arm state when the Glance widget arms NFC directly without launching the app.
  ///
  /// The widget has already written SharedPreferences and started the HCE service.
  /// This method only updates the Flutter-side state to reflect the existing arm.
  void syncArmFromWidget(int remainingSec) {
    _cancelTimers();
    final clamped = remainingSec.clamp(1, AppConstants.armTimeoutSec);
    state = ArmStateData(
      phase: TapSharePhase.armed,
      remainingSec: clamped,
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  /// Transitions to the success state and auto-resets to idle after 4 seconds.
  ///
  /// Called by the share screen in Phase 3 for testing, and by the Phase 4
  /// Kotlin → Flutter tap callback once that is wired up.
  void triggerSuccess() {
    _cancelTimers();
    state = const ArmStateData(phase: TapSharePhase.success);
    // Auto-reset to idle after 4s (matching the spec's 4-second screen reset).
    _successResetTimer = Timer(const Duration(seconds: 4), () {
      if (state.phase == TapSharePhase.success) {
        state = const ArmStateData();
      }
    });
  }

  // ─── Internal ───────────────────────────────────────────────────────────────

  void _onTick(Timer timer) {
    if (state.remainingSec <= 1) {
      // Timeout expired — disarm silently and return to idle.
      timer.cancel();
      _nfc.disarm();
      state = const ArmStateData();
    } else {
      state = state.copyWith(remainingSec: state.remainingSec - 1);
    }
  }

  void _cancelTimers() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _successResetTimer?.cancel();
    _successResetTimer = null;
  }

  String _userMessageForError(NfcErrorCode code) {
    return switch (code) {
      NfcErrorCode.nfcUnavailable => 'This device doesn\'t support NFC.',
      NfcErrorCode.nfcDisabled    => 'NFC is off. Enable it in Settings.',
      NfcErrorCode.noPayload      => 'No contact card found. Please save your card first.',
      _                           => 'Couldn\'t arm NFC. Try again.',
    };
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// The global arm state provider. Consumed by [ShareScreen] and [QrPanel].
final armStateProvider =
    StateNotifierProvider<ArmStateNotifier, ArmStateData>((ref) {
  return ArmStateNotifier(ref);
});
