/// Onboarding flow for first-time TapCard users.
/// Two pages: (0) welcome, (1) NFC availability check.
/// Navigates to the card editor on completion.
/// Visual spec: UI_DIRECTION.md §Onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colours.dart';
import '../../core/constants.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../core/widgets/pressable_widget.dart';
import '../../core/providers/nfc_channel_provider.dart';
import '../../platform/nfc_channel.dart';

// ---------------------------------------------------------------------------
// Entry widget
// ---------------------------------------------------------------------------

/// Onboarding entry point — a two-page flow wrapped in a [PageView].
///
/// Page 0: Welcome — pure typography, single CTA.
/// Page 1: NFC check — queries NFC availability, adapts copy accordingly.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _advanceToNfcPage() {
    _pageController.animateToPage(
      1,
      duration: AppTokens.entrance,
      curve: AppTokens.entrance_,
    );
  }

  void _finishOnboarding() {
    context.go(AppConstants.routeCardEditor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.bgPrimary,
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // user cannot swipe — must tap CTA
        children: [
          _WelcomePage(onContinue: _advanceToNfcPage),
          _NfcPage(onContinue: _finishOnboarding),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 0 — Welcome
// ---------------------------------------------------------------------------

/// Welcome page — pure typography, no illustrations.
/// Spec: UI_DIRECTION.md §Onboarding — Screen 1.
class _WelcomePage extends StatelessWidget {
  const _WelcomePage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),

            // Hero headline — staggered entrance.
            Text(
              'Share your\ncontact.\nJust tap.',
              style: AppTypography.display(size: 40),
            ).animate().fadeIn(
                  duration: AppTokens.entrance,
                  curve: AppTokens.entrance_,
                ).slideY(begin: 12 / 40, end: 0, duration: AppTokens.entrance, curve: AppTokens.entrance_),

            const SizedBox(height: AppTokens.md),

            Text(
              'Hold your phone still. Let theirs touch yours. '
              'They get your contact card instantly — no app needed.',
              style: AppTypography.body(size: 15),
            )
                .animate(delay: const Duration(milliseconds: 80))
                .fadeIn(duration: AppTokens.entrance, curve: AppTokens.entrance_)
                .slideY(begin: 12 / 15, end: 0, duration: AppTokens.entrance, curve: AppTokens.entrance_),

            const Spacer(),

            // CTA — outlined style, no fill.
            _OutlinedButton(label: 'Get Started', onTap: onContinue)
                .animate(delay: const Duration(milliseconds: 160))
                .fadeIn(duration: AppTokens.entrance, curve: AppTokens.entrance_),

            const SizedBox(height: AppTokens.xxl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — NFC Check
// ---------------------------------------------------------------------------

/// NFC availability page — checks hardware state and adapts copy.
/// Spec: UI_DIRECTION.md §Onboarding — Screen 2.
class _NfcPage extends ConsumerStatefulWidget {
  const _NfcPage({required this.onContinue});

  final VoidCallback onContinue;

  @override
  ConsumerState<_NfcPage> createState() => _NfcPageState();
}

class _NfcPageState extends ConsumerState<_NfcPage> {
  NfcAvailability? _nfcState;

  @override
  void initState() {
    super.initState();
    _checkNfc();
  }

  Future<void> _checkNfc() async {
    final state = await ref.read(nfcChannelProvider).isNfcAvailable();
    if (mounted) setState(() => _nfcState = state);
  }

  @override
  Widget build(BuildContext context) {
    final nfc = _nfcState;
    final bool nfcDisabled = nfc != null && nfc.available && !nfc.enabled;
    final bool nfcUnavailable = nfc != null && !nfc.available;

    final String headline = nfcUnavailable
        ? 'QR code mode'
        : nfcDisabled
            ? 'Enable NFC'
            : 'NFC ready';

    final String body = nfcUnavailable
        ? 'Your device doesn\'t have NFC. You can still share your card '
            'via QR code — anyone can scan it with their camera.'
        : nfcDisabled
            ? 'Turn on NFC in Settings so people can receive your card '
                'with a tap. You can also share via QR code.'
            : 'Great — your phone can share your contact card with a tap. '
                'Works with any NFC phone, no app required on their side.';

    final String ctaLabel = nfcDisabled ? 'Open NFC Settings' : 'Continue';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),

            // NFC icon — two phones, line art style, muted.
            const _NfcIconPlaceholder(),

            const SizedBox(height: AppTokens.xl),

            Text(
              headline,
              style: AppTypography.title(size: 28),
            ).animate().fadeIn(duration: AppTokens.entrance, curve: AppTokens.entrance_),

            const SizedBox(height: AppTokens.md),

            Text(body, style: AppTypography.body(size: 15))
                .animate(delay: const Duration(milliseconds: 60))
                .fadeIn(duration: AppTokens.entrance, curve: AppTokens.entrance_),

            if (nfcUnavailable) ...[
              const SizedBox(height: AppTokens.sm),
              Text(
                'NFC works best on iPhone XS and newer.',
                style: AppTypography.body(size: 13)
                    .copyWith(color: AppColours.textTertiary),
              ),
            ],

            const Spacer(),

            if (_nfcState == null)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColours.textTertiary,
                  ),
                ),
              )
            else
              _OutlinedButton(
                label: ctaLabel,
                onTap: widget.onContinue,
              ).animate(delay: const Duration(milliseconds: 120)).fadeIn(
                    duration: AppTokens.entrance,
                    curve: AppTokens.entrance_,
                  ),

            const SizedBox(height: AppTokens.xxl),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

/// Outlined CTA button — 1-dp border, no fill, textPrimary label.
/// Used on both onboarding pages.
class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableWidget(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: AppTokens.minTouchTarget + 4,
        decoration: BoxDecoration(
          border: Border.all(color: AppColours.divider),
          borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        ),
        alignment: Alignment.center,
        child: Text(label, style: AppTypography.bodyMedium(size: 15)),
      ),
    );
  }
}

/// Placeholder for the two-phones NFC icon.
/// Phase 3: replaced with the real SVG asset once assets/icons/nfc_phones.svg exists.
class _NfcIconPlaceholder extends StatelessWidget {
  const _NfcIconPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColours.bgTertiary,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
      ),
      child: const Icon(Icons.nfc, color: AppColours.textTertiary, size: 32),
    );
  }
}
