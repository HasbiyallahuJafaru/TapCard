/// go_router configuration for TapCard.
/// All app routes are declared here. Feature screens are imported from their
/// respective feature directories. Deep links (e.g. tapcard://share) are
/// handled via the redirect / deep-link config below.
library;

import 'package:go_router/go_router.dart';

import '../core/constants.dart';

// Placeholder screens — will be replaced when feature screens are built.
// They are declared here so the router compiles before Phase 3 UI work.
import '../features/splash/splash_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/card_editor/card_editor_screen.dart';
import '../features/share/share_screen.dart';

/// Configures and exposes the app-wide [GoRouter] instance.
abstract final class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: AppConstants.routeSplash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppConstants.routeSplash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppConstants.routeOnboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppConstants.routeCardEditor,
        builder: (context, state) => const CardEditorScreen(),
      ),
      GoRoute(
        path: AppConstants.routeShare,
        builder: (context, state) => const ShareScreen(),
      ),
    ],
  );
}
