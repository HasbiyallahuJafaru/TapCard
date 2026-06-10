/// App-wide string constants for TapCard.
/// All hardcoded domain names, URLs, SharedPreferences keys, and channel names
/// live here. Never inline these strings anywhere else in the codebase.
library;

/// Top-level constants used across the entire TapCard application.
abstract final class AppConstants {
  AppConstants._();

  // ─── Web decoder domain ──────────────────────────────────────────────────────

  /// The domain of the static decoder web page.
  /// Configured via `--dart-define=TAPCARD_DOMAIN=domain` at build time.
  /// Falls back to a localhost placeholder for development builds.
  static const String domain = String.fromEnvironment(
    'TAPCARD_DOMAIN',
    defaultValue: 'localhost:8080',
  );

  /// Full base URL of the decoder page (no trailing slash).
  static String get decoderBaseUrl => 'https://$domain';

  /// Maximum encoded share URL length in characters.
  /// Enforced in url_codec.dart before building the NDEF payload.
  static const int maxUrlLength = 1200;

  // ─── AdMob ───────────────────────────────────────────────────────────────────

  /// AdMob App ID — must be set via `--dart-define=ADMOB_APP_ID=id`.
  /// In debug builds, the test App ID is used as fallback.
  static const String admobAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713', // AdMob test app ID
  );

  /// Native ad unit ID for the post-share success screen.
  /// In debug builds, the test native ad unit ID is used as fallback.
  static const String nativeAdUnitId = String.fromEnvironment(
    'NATIVE_AD_UNIT_ID',
    defaultValue: 'ca-app-pub-3940256099942544/2247696110', // AdMob test native
  );

  // ─── Platform channel names ──────────────────────────────────────────────────

  /// MethodChannel name for NFC HCE arming/disarming. See PLATFORM_CHANNEL.md.
  static const String nfcChannelName = 'tapcard/nfc';

  /// MethodChannel name for widget ↔ app communication. See PLATFORM_CHANNEL.md.
  static const String widgetChannelName = 'tapcard/widget';

  // ─── Hive box names ───────────────────────────────────────────────────────────

  /// Hive box that stores the single [ContactCard] record.
  static const String contactCardBoxName = 'contact_card';

  // ─── NFC arm window ──────────────────────────────────────────────────────────

  /// How long (in seconds) the HCE service stays armed after the user taps arm.
  /// Must stay in sync with NdefHostApduService companion object ARM_DURATION_MS.
  static const int armTimeoutSec = 60;

  // ─── go_router route paths ────────────────────────────────────────────────────

  static const String routeSplash = '/';
  static const String routeOnboarding = '/onboarding';
  static const String routeCardEditor = '/editor';
  static const String routeShare = '/share';
}
