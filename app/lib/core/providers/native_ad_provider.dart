/// Riverpod provider for managing the AdMob native ad lifecycle.
///
/// Loads the next ad in the background so it is ready to show immediately
/// after a successful tap. Only one ad is held in memory at a time.
/// See .claude/MONETIZATION.md for placement rules.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class NativeAdState {
  const NativeAdState({this.ad, this.isLoaded = false});

  final NativeAd? ad;
  final bool isLoaded;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class NativeAdNotifier extends StateNotifier<NativeAdState> {
  NativeAdNotifier() : super(const NativeAdState()) {
    _load();
  }

  NativeAd? _loadingAd;

  void _load() {
    _loadingAd?.dispose();
    _loadingAd = NativeAd(
      adUnitId: AppConstants.nativeAdUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) debugPrint('[NativeAdNotifier] ad loaded');
          if (mounted) state = NativeAdState(ad: ad as NativeAd, isLoaded: true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) debugPrint('[NativeAdNotifier] failed: $error');
          if (mounted) state = const NativeAdState();
        },
        onAdClosed: (_) {
          if (mounted) {
            state = const NativeAdState();
            _load(); // pre-load the next ad
          }
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.small,
      ),
    )..load();
  }

  /// Disposes the current ad and pre-loads a fresh one.
  /// Call after the ad has been shown and dismissed.
  void reload() {
    state.ad?.dispose();
    state = const NativeAdState();
    _load();
  }

  @override
  void dispose() {
    _loadingAd?.dispose();
    state.ad?.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final nativeAdProvider =
    StateNotifierProvider<NativeAdNotifier, NativeAdState>((ref) {
  return NativeAdNotifier();
});
