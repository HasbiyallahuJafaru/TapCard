/// Share screen — the core screen of the TapCard app.
/// Manages three states: idle, armed (countdown ring), and success (checkmark).
/// Also provides the QR code toggle and navigates to the card editor.
/// Visual spec: UI_DIRECTION.md §Share Screen.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colours.dart';
import '../../core/constants.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../core/url_codec.dart';
import '../../core/vcard_builder.dart';
import '../../core/widgets/pressable_widget.dart';
import '../../core/providers/card_repository_provider.dart';
import '../../core/providers/arm_state_provider.dart';
import 'native_ad_card.dart';
import 'nfc_ring_painter.dart';
import 'qr_panel.dart';

/// The core share screen.
///
/// Reads the saved [ContactCard] on build. If no card is saved, immediately
/// redirects to the card editor so the user creates one first.
class ShareScreen extends ConsumerWidget {
  const ShareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(contactCardProvider);
    if (card == null) {
      // No card saved yet — send to editor. WidgetsBinding delays the navigation
      // past the current build frame to avoid calling context.go during build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppConstants.routeCardEditor);
      });
      return const Scaffold(backgroundColor: AppColours.bgPrimary);
    }

    // Build vCard for NFC; also encode URL for QR code.
    String? vCard;
    String? shareUrl;
    String? urlError;
    try {
      vCard = VCardBuilder.build(card);
      final result = UrlCodec.encode(vCard);
      if (result is EncodeSuccess) {
        shareUrl = result.url;
      }
      // URL overflow doesn't block NFC — vCard is sent directly.
    } catch (e) {
      urlError = 'Could not build contact card. Edit your card and try again.';
    }

    return _ShareScreenContent(vCard: vCard, shareUrl: shareUrl, urlError: urlError);
  }
}

/// Stateful inner widget — holds animation and arm-state interactions.
class _ShareScreenContent extends ConsumerStatefulWidget {
  const _ShareScreenContent({this.vCard, this.shareUrl, this.urlError});

  final String? vCard;
  final String? shareUrl;
  final String? urlError;

  @override
  ConsumerState<_ShareScreenContent> createState() => _ShareScreenContentState();
}

class _ShareScreenContentState extends ConsumerState<_ShareScreenContent>
    with SingleTickerProviderStateMixin {
  // Animated radius for the tap-zone circle (idle ↔ armed).
  late final AnimationController _radiusController;
  late final Animation<double> _radiusAnim;

  // Whether to show the AdMob native ad card (420ms delay after success).
  bool _showAd = false;
  Timer? _adTimer;

  @override
  void initState() {
    super.initState();
    _radiusController = AnimationController(
      vsync: this,
      duration: AppTokens.nfcArm,
    );
    _radiusAnim = Tween<double>(
      begin: AppTokens.nfcCircleIdle,
      end: AppTokens.nfcCircleArmed,
    ).animate(CurvedAnimation(parent: _radiusController, curve: AppTokens.spring));
  }

  @override
  void dispose() {
    _adTimer?.cancel();
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _onCircleTap() async {
    final armState = ref.read(armStateProvider);
    if (armState.phase == TapSharePhase.armed) {
      // Tap while armed → disarm.
      _radiusController.reverse();
      await ref.read(armStateProvider.notifier).disarm();
    } else if (armState.phase == TapSharePhase.idle) {
      if (widget.vCard == null) return;
      _radiusController.forward();
      await ref.read(armStateProvider.notifier).arm(widget.vCard!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final armState = ref.watch(armStateProvider);
    final phase = armState.phase;

    // Sync animation when state changes externally (timeout → idle).
    if (phase == TapSharePhase.idle && _radiusController.value > 0) {
      _radiusController.reverse();
    }

    // Schedule ad reveal 420ms after entering success state.
    if (phase == TapSharePhase.success && !_showAd && _adTimer == null) {
      _adTimer = Timer(const Duration(milliseconds: 420), () {
        if (mounted) setState(() => _showAd = true);
        _adTimer = null;
      });
    }
    // Reset ad when returning to idle.
    if (phase == TapSharePhase.idle && _showAd) {
      _showAd = false;
    }

    final bool isArmed   = phase == TapSharePhase.armed;
    final bool isSuccess = phase == TapSharePhase.success;

    final double ringProgress = isArmed
        ? armState.remainingSec / AppConstants.armTimeoutSec
        : isSuccess
            ? 1.0
            : 1.0; // idle: full ring, but nfcIdle colour

    final Color ringColor = isSuccess
        ? AppColours.nfcSuccess
        : isArmed
            ? AppColours.nfcArmed
            : AppColours.nfcIdle;

    return Scaffold(
      backgroundColor: AppColours.bgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Positioned(
              top: 0,
              left: AppTokens.lg,
              right: AppTokens.lg,
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TapCard', style: AppTypography.label(size: 11, uppercase: true)),
                    PressableWidget(
                      onTap: () => context.go(AppConstants.routeCardEditor),
                      child: const SizedBox(
                        width: AppTokens.minTouchTarget,
                        height: AppTokens.minTouchTarget,
                        child: Icon(Icons.edit_outlined,
                            color: AppColours.textSecondary, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Main content ─────────────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // NFC tap-zone circle + ring.
                  AnimatedBuilder(
                    animation: _radiusAnim,
                    builder: (context, _) {
                      final diameter = _radiusAnim.value * 2;
                      return PressableWidget(
                        onTap: _onCircleTap,
                        child: SizedBox(
                          width: diameter + 24, // extra room for ring stroke
                          height: diameter + 24,
                          child: CustomPaint(
                            painter: NfcRingPainter(
                              progress: ringProgress,
                              ringColor: ringColor,
                              strokeWidth: 3,
                            ),
                            child: Center(
                              child: Container(
                                width: diameter,
                                height: diameter,
                                decoration: BoxDecoration(
                                  color: isSuccess
                                      ? AppColours.nfcSuccess.withAlpha(40)
                                      : AppColours.bgTertiary,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: _CircleContent(
                                    phase: phase,
                                    remainingSec: armState.remainingSec),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: AppTokens.xl),

                  // State title — crossfades via AnimatedSwitcher.
                  AnimatedSwitcher(
                    duration: AppTokens.stateChange,
                    child: Text(
                      key: ValueKey(phase),
                      _titleForPhase(phase),
                      style: AppTypography.title(size: 22),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: AppTokens.sm),

                  // State subtitle.
                  AnimatedSwitcher(
                    duration: AppTokens.stateChange,
                    child: Text(
                      key: ValueKey(phase),
                      _subtitleForPhase(phase),
                      style: AppTypography.body(size: 15),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // AdMob native ad — appears 420ms after success.
                  if (_showAd) ...[
                    const SizedBox(height: AppTokens.xl),
                    NativeAdCard(
                      onDismissed: () {
                        if (mounted) setState(() => _showAd = false);
                      },
                    ),
                  ],

                  // Error message (URL too long or no card).
                  if (widget.urlError != null) ...[
                    const SizedBox(height: AppTokens.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                      child: Text(
                        widget.urlError!,
                        style: AppTypography.body(size: 13)
                            .copyWith(color: AppColours.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  if (armState.errorMessage != null) ...[
                    const SizedBox(height: AppTokens.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
                      child: Text(
                        armState.errorMessage!,
                        style: AppTypography.body(size: 13)
                            .copyWith(color: AppColours.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── QR toggle ────────────────────────────────────────────────────
            if (widget.shareUrl != null)
              Positioned(
                bottom: AppTokens.xxl,
                left: 0,
                right: 0,
                child: Center(
                  child: PressableWidget(
                    onTap: () => showQrPanel(
                      context,
                      shareUrl: widget.shareUrl!,
                    ),
                    child: Text(
                      'Show QR Code',
                      style: AppTypography.body(size: 14).copyWith(
                        color: AppColours.textSecondary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColours.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppTokens.entrance, curve: AppTokens.entrance_);
  }

  String _titleForPhase(TapSharePhase phase) {
    return switch (phase) {
      TapSharePhase.idle    => 'Tap to Share',
      TapSharePhase.armed   => 'Ready — Tap Phones Together',
      TapSharePhase.success => 'Shared!',
    };
  }

  String _subtitleForPhase(TapSharePhase phase) {
    return switch (phase) {
      TapSharePhase.idle    => 'Hold your phone still. Tap theirs to yours.',
      TapSharePhase.armed   => 'Keep your screen on.',
      TapSharePhase.success => 'Your contact was delivered.',
    };
  }
}

// ---------------------------------------------------------------------------
// Circle interior content
// ---------------------------------------------------------------------------

/// Shows the appropriate content inside the NFC tap-zone circle.
///
/// Idle: NFC icon. Armed: countdown number. Success: checkmark.
class _CircleContent extends StatelessWidget {
  const _CircleContent({required this.phase, required this.remainingSec});

  final TapSharePhase phase;
  final int remainingSec;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppTokens.stateChange,
      child: switch (phase) {
        TapSharePhase.idle => const Icon(
            Icons.nfc,
            key: ValueKey('idle'),
            color: AppColours.textTertiary,
            size: 36,
          ),
        TapSharePhase.armed => Text(
            key: ValueKey('armed-$remainingSec'),
            '$remainingSec',
            style: AppTypography.mono(size: 32)
                .copyWith(color: AppColours.textPrimary),
          ),
        TapSharePhase.success => const Icon(
            Icons.check,
            key: ValueKey('success'),
            color: AppColours.nfcSuccess,
            size: 36,
          ),
      },
    );
  }
}
