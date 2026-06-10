/// NativeAdCard — renders a single AdMob native ad in the app's visual language.
///
/// Only used on the share success screen. Shown post-tap with a 420ms delay,
/// auto-dismissed after 3s. User can swipe down to dismiss.
/// See .claude/MONETIZATION.md for full placement rules.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/colours.dart';
import '../../core/tokens.dart';
import '../../core/typography.dart';
import '../../core/providers/native_ad_provider.dart';

/// Displays the loaded native ad with the app's styling.
///
/// [onDismissed] is called when the card auto-dismisses or the user swipes it away.
class NativeAdCard extends ConsumerStatefulWidget {
  const NativeAdCard({super.key, required this.onDismissed});

  final VoidCallback onDismissed;

  @override
  ConsumerState<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends ConsumerState<NativeAdCard> {
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    // Auto-dismiss after 3s per MONETIZATION.md §Stream 2 rule 3.
    _autoTimer = Timer(const Duration(seconds: 3), _dismiss);
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  void _dismiss() {
    _autoTimer?.cancel();
    ref.read(nativeAdProvider.notifier).reload();
    widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final adState = ref.watch(nativeAdProvider);
    if (!adState.isLoaded || adState.ad == null) return const SizedBox.shrink();

    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Swipe down to dismiss.
        if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
          _dismiss();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SPONSORED',
              style: AppTypography.label(size: 10, uppercase: true)
                  .copyWith(color: AppColours.textTertiary),
            ),
            const SizedBox(height: AppTokens.xs),
            Container(
              decoration: const BoxDecoration(
                color: AppColours.bgSecondary,
                borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusMd)),
              ),
              clipBehavior: Clip.antiAlias,
              height: 90,
              child: AdWidget(ad: adState.ad!),
            ),
          ],
        ),
      ),
    )
        .animate()
        .slideY(begin: 0.15, end: 0, duration: 280.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 280.ms, curve: Curves.easeOutCubic);
  }
}
