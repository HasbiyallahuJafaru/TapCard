/// Two-stage splash screen — Stage 2 (animated Flutter layer).
/// Stage 1 (OS-level native splash) is configured in flutter_native_splash.yaml.
/// This widget runs the animated wordmark sequence from UI_DIRECTION.md §Splash Screen
/// and navigates to onboarding (no saved card) or share (returning user).
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/colours.dart';
import '../../core/constants.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../core/providers/card_repository_provider.dart';

/// Animated splash screen (Stage 2 of the two-stage splash).
///
/// Animation sequence (per UI_DIRECTION.md):
///   t=0ms    Wordmark fades in (80ms easeOutCubic)
///   t=180ms  Tagline fades + slides in (280ms easeOutCubic)
///   t=500ms  Hold — async check: hasCard?
///   t=600ms  Whole screen fades out (200ms easeInCubic)
///   t=800ms  Navigate to onboarding or share
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _runSplashSequence();
  }

  Future<void> _runSplashSequence() async {
    // Hold window at t=500ms — read card presence while animations play.
    await Future.delayed(const Duration(milliseconds: 500));
    final hasCard = ref.read(cardRepositoryProvider).hasCard();

    // Trigger the screen fade-out at t=600ms.
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _exiting = true);

    // Navigate at t=800ms (200ms fade duration).
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      context.go(
        hasCard ? AppConstants.routeShare : AppConstants.routeOnboarding,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColours.bgPrimary,
      body: AnimatedOpacity(
        opacity: _exiting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInCubic,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Wordmark — fades in at t=0ms over 80ms.
              Text(
                'TapCard',
                style: AppTypography.title(size: 28),
              ).animate().fadeIn(
                    duration: const Duration(milliseconds: 80),
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: AppTokens.sm),

              // Tagline — fades + slides up, delayed 180ms.
              Text(
                'TAP. SHARE. DONE.',
                style: AppTypography.label(size: 12, uppercase: true).copyWith(
                  letterSpacing: 0.14 * 12,
                  color: AppColours.textTertiary,
                ),
              )
                  .animate(
                    delay: const Duration(milliseconds: 180),
                  )
                  .fadeIn(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  )
                  .slideY(
                    begin: 4 / 16, // 4dp expressed as a fraction of widget height
                    end: 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
