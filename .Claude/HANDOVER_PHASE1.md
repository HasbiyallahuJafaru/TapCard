# TapCard — Phase 1 Handover
> Read this at the start of the next session BEFORE touching any code.
> It records every decision made, every constraint hit, and exactly where to pick up.

---

## Session Summary

**Date:** 2026-06-09
**Phase completed:** Phase 1 — Flutter-side core plumbing (partial)
**Status:** Flutter scaffold + design system + data layer + core utilities — all done, tests green.
**Remaining in Phase 1:** Kotlin native layer (NFC HCE) + AndroidManifest wiring.

---

## What Was Built This Session

### Flutter app scaffolded at `app/`

```
app/
├── pubspec.yaml                          ← all deps resolved (see constraints below)
├── lib/
│   ├── main.dart                         ← Hive init, ProviderScope, MaterialApp.router
│   ├── core/
│   │   ├── tokens.dart                   ← AppTokens (spacing, radius, durations, curves)
│   │   ├── colours.dart                  ← AppColours (full palette from UI_DIRECTION.md)
│   │   ├── typography.dart               ← AppTypography (Syne / DM Sans / DM Mono)
│   │   ├── constants.dart                ← domain, channel names, box names, route paths
│   │   ├── router.dart                   ← go_router with 4 stub screens
│   │   ├── vcard_builder.dart            ← vCard 3.0 builder, correct escape order ✓
│   │   └── url_codec.dart                ← base64url encode/decode + 1200-char guard ✓
│   ├── data/
│   │   ├── models/contact_card.dart      ← ContactCard + manual Hive TypeAdapter (typeId 0)
│   │   └── repositories/card_repository.dart ← single-card Hive repository
│   ├── platform/                         ← EMPTY — nfc_channel.dart goes here next session
│   └── features/
│       ├── splash/splash_screen.dart     ← stub (Phase 3)
│       ├── onboarding/onboarding_screen.dart ← stub (Phase 3)
│       ├── card_editor/card_editor_screen.dart ← stub (Phase 3)
│       └── share/share_screen.dart       ← stub (Phase 3)
└── test/
    ├── core/
    │   ├── vcard_builder_test.dart       ← 21 tests — ALL PASSING ✓
    │   └── url_codec_test.dart           ← 16 tests — ALL PASSING ✓
    └── widget_test.dart                  ← emptied (default counter test removed)
```

**Test result:** `flutter test test/core/` → **37/37 passing**
**Analysis:** `flutter analyze` → **0 issues**

---

## Critical Dependency Constraints (DO NOT IGNORE)

The current Flutter SDK on this machine pins `meta` at `1.17.0` via `flutter_test`. This creates hard conflicts with several "latest" package versions. The following constraints are **intentional and load-bearing** — do not upgrade them without first upgrading Flutter:

| Package | Pinned version | Why constrained |
|---|---|---|
| `flutter_native_splash` | `^2.3.13` | 2.4.x needs `meta ^1.18.0` — conflicts with SDK |
| `flutter_riverpod` | `^2.6.1` | 3.x needs `meta ^1.18.0` — conflicts with SDK |
| `riverpod_annotation` | `^2.6.1` | Same chain as flutter_riverpod |

**Codegen packages NOT installed** (`hive_generator`, `riverpod_generator`, `build_runner`): all three conflict via `source_gen` / `build` / `meta` version chains. Do not add them without resolving the meta constraint first.

**Consequence:** 
- Hive TypeAdapter for `ContactCard` is **hand-written** in `contact_card.dart`. Never run `build_runner` expecting to regenerate it — it will fail.
- Riverpod providers are **written manually** (no `@riverpod` annotations). Use `Provider`, `StateNotifierProvider`, `FutureProvider` etc. directly.

---

## Architecture Decisions Made

1. **Riverpod providers location:** `lib/core/providers/` — directory exists, no files yet. Create providers here.
2. **Hive TypeAdapter field index map** (FROZEN — never reorder):
   - `0` → `fullName`
   - `1` → `cellPhone`
   - `2` → `email`
   - `3` → `company`
   - `4` → `jobTitle`
   - `5` → `note`
   - `6` → `photoPath`
3. **vCard escape order** (load-bearing — see `vcard_builder.dart`): backslash → semicolon → comma → strip `\r` → replace `\n` with literal `\n`. Order is not negotiable.
4. **URL codec:** base64url, no padding, 1200-char hard limit. Returns `EncodeSuccess` or `EncodeTooLong` sealed class — never throws on length overflow.
5. **No `print()` anywhere.** All debug logging via `if (kDebugMode) { debugPrint('[ClassName] ...'); }`.

---

## What To Build Next (Phase 1 — Kotlin native layer)

This is the remaining Phase 1 work. Do it in this order:

### Step 1 — Android resource files

**File:** `app/android/app/src/main/res/xml/apduservice.xml`
```xml
<host-apdu-service
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:description="@string/service_name"
    android:requireDeviceUnlock="true">
    <aid-group
        android:description="@string/service_name"
        android:category="other">
        <aid-filter android:name="D2760000850101" />
    </aid-group>
</host-apdu-service>
```

**File:** `app/android/app/src/main/res/values/strings.xml` — add:
```xml
<string name="service_name">TapCard NFC</string>
```

---

### Step 2 — `NdefHostApduService.kt`

**Location:** `app/android/app/src/main/kotlin/com/tapcard/app/NdefHostApduService.kt`

Full APDU state machine. States: `IDLE → SELECTED_APP → SELECTED_CC → SELECTED_NDEF`.

Key implementation points (all from `.claude/NFC_SPEC.md` — read it):
- AID: `D2 76 00 00 85 01 01`
- CC file response: exact 15-byte sequence (see NFC_SPEC.md §3 READ BINARY CC File)
- NDEF file ID: `E1 04`
- On every `processCommandApdu`: read SharedPreferences fresh (service can be cold-started by OS)
- Expiry check on every SELECT AID — if expired, call `disarm()` and return `SW_SECURITY_STATUS_NOT_SATISFIED` (`69 82`)
- NDEF message: URI record, prefix code `0x04` (`https://`), payload = URL bytes after stripping `https://`
- Max CC file NDEF size field: calculate dynamically from actual NDEF length + 2

SharedPreferences keys (in `companion object` — never inline):
```kotlin
const val PREFS_NAME        = "tapcard_nfc"
const val KEY_NDEF_URL      = "ndef_url"
const val KEY_IS_ARMED      = "is_armed"
const val KEY_EXPIRES_AT_MS = "expires_at_ms"
const val ARM_DURATION_MS   = 60_000L
```

---

### Step 3 — `NfcPlugin.kt`

**Location:** `app/android/app/src/main/kotlin/com/tapcard/app/NfcPlugin.kt`

MethodChannel handler for `tapcard/nfc`. Methods to implement (full contract in `.claude/PLATFORM_CHANNEL.md`):
- `setPayload(url: String): Boolean`
- `arm(timeoutSec: Int): Boolean`
- `disarm(): Unit`
- `isNfcAvailable(): Map<String, Boolean>`
- `getArmState(): Map<String, Any>`

Error codes (PlatformException):
- `INVALID_URL`, `PAYLOAD_TOO_LONG`, `NO_PAYLOAD`, `NFC_UNAVAILABLE`, `NFC_DISABLED`

---

### Step 4 — `MainActivity.kt`

**Location:** `app/android/app/src/main/kotlin/com/tapcard/app/MainActivity.kt`

Replace the default scaffolded `MainActivity`. Register `NfcPlugin` in `configureFlutterEngine`.

---

### Step 5 — `nfc_channel.dart`

**Location:** `app/lib/platform/nfc_channel.dart`

Typed Dart wrapper. Raw `MethodChannel` must not be called outside this file.
See `.claude/PLATFORM_CHANNEL.md` for the full method signatures and error types to define:
- `NfcAvailability` — value class with `available` and `enabled` booleans
- `ArmState` — value class with `armed` and `remainingSec`
- `TapCardNfcException` — wraps `PlatformException`, exposes `NfcErrorCode` enum
- `NfcErrorCode` enum: `invalidUrl`, `payloadTooLong`, `noPayload`, `nfcUnavailable`, `nfcDisabled`, `unknown`

---

### Step 6 — `AndroidManifest.xml` wiring

**Location:** `app/android/app/src/main/AndroidManifest.xml`

Add:
1. NFC uses-feature (required):
   ```xml
   <uses-feature android:name="android.hardware.nfc" android:required="false" />
   <uses-permission android:name="android.permission.NFC" />
   ```
2. The `NdefHostApduService` entry with AID meta-data (exact XML in `.claude/NFC_SPEC.md`)
3. AdMob App ID meta-data placeholder:
   ```xml
   <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="${ADMOB_APP_ID}" />
   ```

---

### Step 7 — APDU state machine tests (Kotlin)

Write unit tests for `NdefHostApduService` with mock byte sequences covering:
- Happy path: full SELECT AID → SELECT CC → READ CC → SELECT NDEF → READ length → READ body
- Disarmed service returns `69 82` on SELECT AID
- Expired service auto-disarms and returns `69 82`
- Unknown command returns `6D 00`
- READ before SELECT AID returns `69 82`

---

## Session Startup Checklist for Next Session

```
1. Read .claude/PROJECT.md          ← single source of truth
2. Read .claude/NFC_SPEC.md         ← every byte is load-bearing
3. Read .claude/PLATFORM_CHANNEL.md ← channel contract is frozen
4. Read .claude/CODE_STANDARDS.md   ← quality gate
5. Read this file (HANDOVER_PHASE1.md)
6. Run: cd app && flutter analyze   ← confirm still clean before starting
7. Run: cd app && flutter test test/core/  ← confirm 37/37 still passing
```

---

## Known Issues / Watch Out For

- **`app/android/app/src/main/kotlin/com/tapcard/app/MainActivity.kt`** — currently the default Flutter scaffolded version. It will need to be rewritten to register `NfcPlugin`, not just extend `FlutterActivity`.
- **`app/android/app/src/main/AndroidManifest.xml`** — currently the default scaffolded version. Read it before writing — do not blindly overwrite.
- **`app/android/app/build.gradle`** — check `minSdk`. HCE requires API 19+; recommend `minSdk = 23` (covers 98%+ of active Android devices as of 2026).
- The `app/lib/core/providers/` directory exists but is empty. Providers for `CardRepository`, `NfcChannel`, and arm state will be created in Phase 1 Step 7 or Phase 3 (whichever needs them first).
- `flutter_native_splash` is installed but not yet configured. A `flutter_native_splash.yaml` config file needs to be created at `app/` root and `dart run flutter_native_splash:create` run. Do this in Phase 3 after the wordmark SVG asset exists.

---

## File Tree Sanity Check

Before writing Kotlin, confirm this path exists:
```
app/android/app/src/main/kotlin/com/tapcard/app/
```
If it doesn't, the package was scaffolded differently — check `app/android/app/src/main/` manually.
