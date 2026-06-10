/// TapCard app entry point.
/// Initialises Hive, registers the ContactCard adapter, and launches the app
/// wrapped in a ProviderScope. This file wires the platform together —
/// feature code lives in lib/features/.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/colours.dart';
import 'core/providers/arm_state_provider.dart';
import 'core/providers/nfc_channel_provider.dart';
import 'core/router.dart';
import 'data/models/contact_card.dart';
import 'data/repositories/card_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Hive with the Flutter path provider integration.
  await Hive.initFlutter();

  // Register the manually-written ContactCard adapter before opening any box.
  Hive.registerAdapter(ContactCardAdapter());

  // Open the contact card box so the repository can access it synchronously.
  await CardRepository.openBox();

  // Initialise AdMob SDK before any ad is requested.
  await MobileAds.instance.initialize();

  runApp(
    const ProviderScope(
      child: TapCardApp(),
    ),
  );
}

/// Root widget. Provides the go_router configuration and the app-wide theme.
/// Also registers reverse platform-channel handlers (NFC tap success, widget arm).
class TapCardApp extends ConsumerStatefulWidget {
  const TapCardApp({super.key});

  @override
  ConsumerState<TapCardApp> createState() => _TapCardAppState();
}

class _TapCardAppState extends ConsumerState<TapCardApp> {
  @override
  void initState() {
    super.initState();
    // Wire Kotlin → Flutter reverse channel: NFC tap confirmed.
    // Called by MainActivity when NdefHostApduService signals NDEF body served.
    ref.read(nfcChannelProvider).setTapSuccessHandler(() {
      ref.read(armStateProvider.notifier).triggerSuccess();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TapCard',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: ThemeData(
        // Dark background throughout — matches AppColours.bgPrimary exactly.
        scaffoldBackgroundColor: AppColours.bgPrimary,
        colorScheme: const ColorScheme.dark(
          surface: AppColours.bgPrimary,
          primary: AppColours.accent,
          error: AppColours.error,
        ),
        // Disable splash/highlight effects — PressableWidget handles tap feedback.
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        // No default AppBar styling — screens own their own headers.
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColours.bgPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
    );
  }
}
