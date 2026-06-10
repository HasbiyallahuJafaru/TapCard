# TapCard — Phase 3 Handover
> Read this at the start of the next session BEFORE touching any code.

---

## Session Summary

**Date:** 2026-06-10
**Phase completed:** Phase 3 — App UI
**Status:** All Phase 3 items done. `flutter analyze` clean. 37/37 tests passing.
**Next phase:** Phase 4 — Glance widget + AdMob + hardening.

---

## What Was Built in Phase 3

### New files

```
app/lib/
├── core/
│   ├── providers/
│   │   ├── card_repository_provider.dart  ← cardRepositoryProvider, contactCardProvider
│   │   ├── nfc_channel_provider.dart      ← nfcChannelProvider
│   │   └── arm_state_provider.dart        ← ArmStateNotifier, armStateProvider, TapSharePhase enum
│   └── widgets/
│       └── pressable_widget.dart          ← PressableWidget (scale 1→0.97 tap feedback)
├── features/
│   ├── splash/
│   │   └── splash_screen.dart             ← REPLACED stub — animated wordmark sequence
│   ├── onboarding/
│   │   └── onboarding_screen.dart         ← REPLACED stub — 2-page PageView flow
│   ├── card_editor/
│   │   └── card_editor_screen.dart        ← REPLACED stub — full form + URL length indicator
│   └── share/
│       ├── share_screen.dart              ← REPLACED stub — idle/armed/success states
│       ├── nfc_ring_painter.dart          ← NEW — CustomPainter for countdown arc
│       └── qr_panel.dart                  ← NEW — QR bottom sheet + copy link
└── assets/
    ├── splash/.keep                        ← placeholder (real SVG goes here in Phase 4)
    └── icons/.keep                         ← placeholder (NFC icon SVG goes here in Phase 4)
```

### `AppConstants` additions (constants.dart)

```dart
static const int armTimeoutSec = 60;
```

---

## Architecture Decisions Made in Phase 3

1. **Providers in `lib/core/providers/`** — three files, one concern each.
   - `contactCardProvider` is a plain `Provider<ContactCard?>` (not reactive stream).
     After editor save, call `ref.invalidate(contactCardProvider)` to refresh.
   - `armStateProvider` is a `StateNotifierProvider` — the single source of truth
     for the share screen's arm/disarm/countdown lifecycle.

2. **`PressableWidget` is the only allowed tap wrapper.** Raw `GestureDetector` /
   `InkWell` must not appear on visible interactive elements. `PressableWidget`
   provides 1.0→0.97 scale + `HapticFeedback.lightImpact` on every tap.

3. **Splash screen uses `AnimatedOpacity` for the exit fade** (not `flutter_animate`)
   so it can be triggered by a `setState` call after an async navigation check.
   The entrance animations (wordmark + tagline) use `flutter_animate`.

4. **Onboarding is a `PageController`-driven `PageView`** with
   `NeverScrollableScrollPhysics` — user advances only by tapping the CTA button.

5. **Card editor computes URL length live** using `VCardBuilder.build` +
   `UrlCodec.computeUrlLength` on every keystroke. Save is blocked if
   `_encodedLength > AppConstants.maxUrlLength`.

6. **Share screen success state** — `triggerSuccess()` on `ArmStateNotifier` is
   the entry point. In Phase 3 it is not wired to a real NFC tap event (no
   Kotlin → Flutter callback exists yet). Phase 4 task: add a reverse
   `MethodChannel` call from `NdefHostApduService` after a complete NDEF read.

7. **NFC ring radius animation** — `AnimationController` with `elasticOut` curve
   drives `nfcCircleIdle (80dp) → nfcCircleArmed (120dp)`. The `NfcRingPainter`
   CustomPainter draws the countdown arc separately from the radius.

8. **QR panel** — `showModalBottomSheet` with `isScrollControlled: true`.
   Uses `qr_flutter`'s `QrImageView`. Copy link uses `Clipboard.setData`.

---

## Known Issues / Watch Out For in Phase 4

- **`assets/splash/` and `assets/icons/` contain only `.keep` placeholder files.**
  `flutter_native_splash` is installed but `flutter_native_splash.yaml` does not
  exist at `app/` root. Before configuring it, add `wordmark.svg` to
  `assets/splash/` and run `dart run flutter_native_splash:create`.

- **Success detection is Phase 4.** The share screen's `TapSharePhase.success`
  state is never entered in production yet. Add a Kotlin `MethodChannel` call
  from `NdefHostApduService.processCommandApdu` after the NDEF body READ BINARY
  completes successfully. The Dart side calls
  `ref.read(armStateProvider.notifier).triggerSuccess()` in the handler.

- **`widget_channel.dart` does not exist.** Still needed for Phase 4 Glance widget.

- **`TapCardWidget.kt` (Glance widget) does not exist.** Phase 4.

- **AdMob `NativeAdCard` does not exist.** Phase 4. The share screen's success
  state should show it 420ms after `TapSharePhase.success` is entered.

- **No `PreferencesRepository`.** The splash screen uses only `hasCard()` to
  decide whether to show onboarding. "Is first launch" is implicitly: no card
  = show onboarding. This is correct for MVP — add a real pref if you need
  independent first-launch tracking.

- **`_NfcIconPlaceholder` in onboarding** uses a Material `Icons.nfc` icon.
  Replace with the real two-phones SVG asset in Phase 4 once it exists.

- **Kotlin → Flutter `armFromWidget` reverse channel** is not wired in Flutter yet.
  The `PLATFORM_CHANNEL.md` describes the handler that should be registered in
  `MainActivity.kt`. Add it in Phase 4 alongside the widget build.

---

## Session Startup Checklist for Phase 4

```
1. Read .claude/PROJECT.md
2. Read .claude/UI_DIRECTION.md §Glance Widget Direction
3. Read .claude/MONETIZATION.md §Stream 2 — AdMob Native Ad
4. Read .claude/PLATFORM_CHANNEL.md §Channel: tapcard/widget
5. Read this file (HANDOVER_PHASE3.md)
6. Run: cd app && flutter analyze          ← confirm still clean
7. Run: cd app && flutter test test/core/  ← confirm 37/37 still passing
```

---

## File Tree Snapshot (end of Phase 3)

```
tapcard/
├── .claude/
│   ├── PROJECT.md
│   ├── CODE_STANDARDS.md
│   ├── NFC_SPEC.md
│   ├── PLATFORM_CHANNEL.md
│   ├── UI_DIRECTION.md
│   ├── MONETIZATION.md
│   ├── HANDOVER_PHASE1.md
│   ├── HANDOVER_PHASE2.md
│   └── HANDOVER_PHASE3.md   ← this file
├── app/
│   ├── pubspec.yaml
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── tokens.dart
│   │   │   ├── colours.dart
│   │   │   ├── typography.dart
│   │   │   ├── constants.dart           ← added armTimeoutSec
│   │   │   ├── router.dart
│   │   │   ├── vcard_builder.dart
│   │   │   ├── url_codec.dart
│   │   │   ├── providers/
│   │   │   │   ├── card_repository_provider.dart
│   │   │   │   ├── nfc_channel_provider.dart
│   │   │   │   └── arm_state_provider.dart
│   │   │   └── widgets/
│   │   │       └── pressable_widget.dart
│   │   ├── data/
│   │   │   ├── models/contact_card.dart
│   │   │   └── repositories/card_repository.dart
│   │   ├── features/
│   │   │   ├── splash/splash_screen.dart        ← animated
│   │   │   ├── onboarding/onboarding_screen.dart ← 2-page flow
│   │   │   ├── card_editor/card_editor_screen.dart ← form + length bar
│   │   │   └── share/
│   │   │       ├── share_screen.dart            ← idle/armed/success
│   │   │       ├── nfc_ring_painter.dart
│   │   │       └── qr_panel.dart
│   │   └── platform/
│   │       └── nfc_channel.dart
│   ├── assets/
│   │   ├── splash/.keep
│   │   └── icons/.keep
│   ├── test/core/   ← 37 tests, all passing
│   └── android/app/src/main/kotlin/com/tapcard/tapcard/
│       ├── MainActivity.kt
│       ├── NdefApduProcessor.kt
│       ├── NdefHostApduService.kt
│       └── NfcPlugin.kt
└── web/
    ├── index.html
    └── netlify.toml
```
