# TapCard — Phase 4 Handover
> Read this at the start of the next session BEFORE touching any code.

---

## Session Summary

**Date:** 2026-06-10
**Phase completed:** Phase 4 — Glance widget + AdMob + hardening
**Status:** All Phase 4 items built. Pending: `flutter pub get` + `flutter analyze` + device test.
**Next phase:** Phase 5 — OEM testing, Play Store listing, release signing.

---

## What Was Built in Phase 4

### New Dart/Flutter files

```
app/lib/
├── platform/
│   └── widget_channel.dart        ← tapcard/widget reverse handler (armFromWidget)
├── core/providers/
│   └── native_ad_provider.dart    ← NativeAdNotifier + nativeAdProvider (Riverpod)
└── features/share/
    └── native_ad_card.dart        ← NativeAdCard widget (post-success AdMob native ad)
```

### Modified Dart/Flutter files

| File | What changed |
|---|---|
| `pubspec.yaml` | Added `google_mobile_ads: ^5.1.0` |
| `main.dart` | Added `MobileAds.instance.initialize()`, converted `TapCardApp` to `ConsumerStatefulWidget`, registered `onTapSuccess` reverse handler |
| `core/providers/arm_state_provider.dart` | Added `syncArmFromWidget(remainingSec)` — syncs Flutter state when widget arms HCE directly |
| `platform/nfc_channel.dart` | Added `setTapSuccessHandler()` — registers Kotlin → Flutter `onTapSuccess` reverse call |
| `features/share/share_screen.dart` | Wired `NativeAdCard` with 420ms delay on success; added `dart:async` import |

### New Kotlin files

```
android/app/src/main/kotlin/com/tapcard/tapcard/
└── widget/
    ├── TapCardWidget.kt          ← GlanceAppWidget (idle + armed states)
    ├── TapCardWidgetReceiver.kt  ← GlanceAppWidgetReceiver
    └── ArmNfcAction.kt           ← ActionCallback: writes SharedPreferences, broadcasts WIDGET_ARMED
```

### Modified Kotlin files

| File | What changed |
|---|---|
| `NdefApduProcessor.kt` | Added `onNdefServed: (() -> Unit)?` param; fires once after NDEF body read at offset ≥ 2 |
| `NdefHostApduService.kt` | Passes `onNdefServed` lambda that sends `ACTION_NFC_TAPPED` local broadcast |
| `MainActivity.kt` | Registers `tapcard/widget` MethodChannel; registers `nfcTappedReceiver` (local broadcast → `onTapSuccess` Flutter call) and `widgetArmedReceiver` (WIDGET_ARMED → `armFromWidget` Flutter call) |
| `build.gradle.kts` | Added Glance (`1.1.0`) + LocalBroadcastManager (`1.1.0`) dependencies |
| `AndroidManifest.xml` | Added `TapCardWidgetReceiver` with APPWIDGET_UPDATE + WIDGET_REFRESH intent filters |

### New Android resource files

```
android/app/src/main/res/
├── xml/tapcard_widget_info.xml          ← AppWidgetProviderInfo (2×1 widget)
├── layout/tapcard_widget_initial_layout.xml  ← Placeholder layout for launcher
└── values/strings.xml                   ← Added widget_description string
```

---

## Architecture Decisions Made in Phase 4

1. **NFC tap success flow (Kotlin → Flutter):**
   - `NdefApduProcessor.onNdefServed` fires at most once per field session (guarded by `ndefBodyServed` flag), after the NDEF body READ BINARY at offset ≥ 2 succeeds.
   - `NdefHostApduService` uses `LocalBroadcastManager` to send `ACTION_NFC_TAPPED`.
   - `MainActivity` receives it in `nfcTappedReceiver` (registered in `onResume`, unregistered in `onPause`) and calls `nfcChannel.invokeMethod("onTapSuccess", null)`.
   - Flutter's `NfcChannel.setTapSuccessHandler()` receives it and calls `armStateProvider.notifier.triggerSuccess()`.
   - This is live only when the app is in the foreground. Background success detection is acceptable for MVP (widget arms → user walks over → tap happens → app is opened → success state).

2. **Widget arming flow:**
   - `ArmNfcAction.onAction` writes `is_armed + expires_at_ms` to SharedPreferences directly — no Flutter launch.
   - It then sends a `WIDGET_ARMED` ordered broadcast (package-restricted) so `MainActivity` can notify Flutter if in foreground.
   - `TapCardWidget` re-reads SharedPreferences on every `provideGlance` call.
   - `ArmNfcAction` schedules a one-shot `AlarmManager` to fire at `expiresAt + 1s`, triggering `TapCardWidgetReceiver.onReceive` which updates the widget back to idle.

3. **`ArmStateNotifier.syncArmFromWidget`** — does NOT call `arm()` again (that would double-arm the HCE service). Sets the Dart-side state to `armed` and starts the countdown timer so the share screen reflects the widget's arm.

4. **AdMob initialisation** — `MobileAds.instance.initialize()` is called in `main()` before `runApp`. This is the correct placement per AdMob SDK docs — must be called before any ad is requested.

5. **`NativeAdNotifier`** pre-loads an ad immediately on construction and reloads after each `reload()` call. The ad is kept alive until the share screen dismisses it. If no ad is loaded when success fires, `NativeAdCard` renders `SizedBox.shrink()` gracefully.

6. **Glance widget font** — Glance does not support Google Fonts. All widget text uses `FontFamily.SansSerif` / `FontFamily.Monospace`. The visual approximation of the NFC icon is the `((·))` Unicode glyph in monospace — replace with a vector drawable in Phase 5 if desired.

---

## Known Issues / Watch Out For in Phase 5

- **`LocalBroadcastManager` is deprecated** in newer AndroidX. It works fine for API 23+ (our min SDK) and is the safest in-process broadcast mechanism available without introducing a foreground service. If you see a deprecation warning in the Kotlin compiler, suppress it with `@Suppress("DEPRECATION")` — do not replace it with a global broadcast.

- **Widget does not show a live countdown.** The armed state shows the initial `remainingSec` value computed when `provideGlance` runs. The `AlarmManager` expiry alarm triggers a refresh when the arm expires, so the widget eventually returns to idle. A per-second countdown would require `AppWidgetManager` or WorkManager polling — not worth the battery cost for MVP.

- **`flutter_native_splash.yaml` still does not exist.** The native splash (Stage 1) is not yet configured. Before release: add `wordmark.svg` to `assets/splash/`, create `flutter_native_splash.yaml` at `app/`, and run `dart run flutter_native_splash:create`.

- **AdMob real unit IDs must be set before release.** Currently using test IDs (`ca-app-pub-3940256099942544/2247696110`). Set `--dart-define=NATIVE_AD_UNIT_ID=<real-id>` and `--dart-define=ADMOB_APP_ID=<real-id>` in the release build command or CI.

- **`widget_channel.dart` uses a `WidgetRef`** for the `registerWidgetChannelHandler` helper function, but it is not currently called anywhere. The widget arm notification is handled directly by `MainActivity` calling `widgetChannel.invokeMethod("armFromWidget", ...)`, which the Flutter `widget_channel.dart`'s `setMethodCallHandler` will pick up. To activate: call `registerWidgetChannelHandler(ref)` from `_TapCardAppState.initState` (alongside the `setTapSuccessHandler` call). Phase 5 task.

- **`MissingPluginException` on non-Android platforms.** The app is Android-only but `setTapSuccessHandler` and `setMethodCallHandler` will throw on web/desktop if ever tested. Guard with `Platform.isAndroid` if needed.

---

## Session Startup Checklist for Phase 5

```
1. Read .claude/PROJECT.md
2. Read .claude/NFC_SPEC.md §Failure modes
3. Read this file (HANDOVER_PHASE4.md)
4. Run: cd app && flutter pub get
5. Run: cd app && flutter analyze          ← must be clean
6. Run: cd app && flutter test test/core/  ← 37/37 must still pass
7. flutter run on physical Android device with NFC
```

---

## File Tree Snapshot (end of Phase 4)

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
│   ├── HANDOVER_PHASE3.md
│   └── HANDOVER_PHASE4.md   ← this file
├── app/
│   ├── pubspec.yaml                     ← + google_mobile_ads ^5.1.0
│   ├── lib/
│   │   ├── main.dart                    ← AdMob init + ConsumerStatefulWidget + onTapSuccess
│   │   ├── core/
│   │   │   ├── tokens.dart
│   │   │   ├── colours.dart
│   │   │   ├── typography.dart
│   │   │   ├── constants.dart
│   │   │   ├── router.dart
│   │   │   ├── vcard_builder.dart
│   │   │   ├── url_codec.dart
│   │   │   ├── providers/
│   │   │   │   ├── card_repository_provider.dart
│   │   │   │   ├── nfc_channel_provider.dart
│   │   │   │   ├── arm_state_provider.dart  ← + syncArmFromWidget
│   │   │   │   └── native_ad_provider.dart  ← NEW
│   │   │   └── widgets/
│   │   │       └── pressable_widget.dart
│   │   ├── data/
│   │   │   ├── models/contact_card.dart
│   │   │   └── repositories/card_repository.dart
│   │   ├── features/
│   │   │   ├── splash/splash_screen.dart
│   │   │   ├── onboarding/onboarding_screen.dart
│   │   │   ├── card_editor/card_editor_screen.dart
│   │   │   └── share/
│   │   │       ├── share_screen.dart        ← + NativeAdCard wiring
│   │   │       ├── nfc_ring_painter.dart
│   │   │       ├── qr_panel.dart
│   │   │       └── native_ad_card.dart      ← NEW
│   │   └── platform/
│   │       ├── nfc_channel.dart             ← + setTapSuccessHandler
│   │       └── widget_channel.dart          ← NEW
│   ├── assets/
│   │   ├── splash/.keep
│   │   └── icons/.keep
│   ├── test/core/   ← 37 tests, should still pass
│   └── android/app/src/main/
│       ├── AndroidManifest.xml              ← + TapCardWidgetReceiver
│       ├── kotlin/com/tapcard/tapcard/
│       │   ├── MainActivity.kt              ← + widget channel + broadcast receivers
│       │   ├── NdefApduProcessor.kt         ← + onNdefServed callback
│       │   ├── NdefHostApduService.kt       ← + ACTION_NFC_TAPPED broadcast
│       │   ├── NfcPlugin.kt
│       │   └── widget/
│       │       ├── TapCardWidget.kt         ← NEW
│       │       ├── TapCardWidgetReceiver.kt ← NEW
│       │       └── ArmNfcAction.kt          ← NEW
│       └── res/
│           ├── xml/tapcard_widget_info.xml  ← NEW
│           ├── layout/tapcard_widget_initial_layout.xml ← NEW
│           └── values/strings.xml           ← + widget_description
└── web/
    ├── index.html
    └── netlify.toml
```
