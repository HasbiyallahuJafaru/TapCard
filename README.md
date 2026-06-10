# TapCard

> Tap your phone. Share your contact. No app required on the other side.

TapCard turns your Android phone into a contactless business card. Hold it against any NFC-capable phone — Android or iPhone XS and newer — and the receiver's browser opens a page with your contact details and a one-tap Save button. No app to install. No account to create. No internet connection required on your side.

QR code is always available as a universal fallback for older iPhones and non-NFC devices.

---

## How It Works

```
You (TapCard)          Their phone
─────────────          ───────────
Arm sharing      →
                 ←     NFC read (HCE)
                        Opens URL in browser
                        Decodes contact from URL fragment
                        Renders contact card
                        One tap → saves to Contacts
```

The share URL looks like this:

```
https://tapcard.app/#<base64url-encoded-vCard>
```

The contact data lives entirely in the URL fragment. It never touches a server. The static web page decodes it in the browser — zero backend, zero database, zero user accounts.

---

## Repository Layout

```
tapcard/
├── app/                        Flutter application (Android)
│   ├── lib/
│   │   ├── core/               Design tokens, typography, colours, router, utilities
│   │   ├── data/               ContactCard model (Hive), CardRepository
│   │   ├── features/           Splash, Onboarding, Card Editor, Share screen
│   │   └── platform/           nfc_channel.dart — typed MethodChannel wrapper
│   ├── android/
│   │   └── app/src/main/kotlin/com/tapcard/tapcard/
│   │       ├── MainActivity.kt
│   │       ├── NdefApduProcessor.kt   APDU state machine (pure Kotlin, testable)
│   │       ├── NdefHostApduService.kt Android HCE service wrapper
│   │       └── NfcPlugin.kt           tapcard/nfc MethodChannel handler
│   └── test/core/              37 unit tests — vCard builder + URL codec
└── web/                        Static decoder page (Netlify) — Phase 2
    ├── index.html
    └── netlify.toml
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| App UI | Flutter (Dart) |
| Local storage | Hive |
| State management | Riverpod |
| Routing | go_router |
| NFC emulation | Native Kotlin — Android Host Card Emulation (HCE) |
| Home widget | Jetpack Glance (Phase 4) |
| QR code | qr_flutter |
| Web decoder | Vanilla HTML / CSS / JS — no frameworks, no build step |
| Hosting | Netlify |
| Ads | Google AdMob — native ads only, post-share only |

---

## NFC Technical Summary

TapCard emulates an **NFC Forum Type 4 Tag** using Android Host Card Emulation. The AID is `D2 76 00 00 85 01 01` (standard Type 4 Tag AID). The NDEF payload is a single URI record.

The HCE service (`NdefHostApduService`) implements the full APDU state machine:

```
IDLE → SELECTED_APP → SELECTED_CC → SELECTED_NDEF
```

Key behaviours:
- **Armed for 60 seconds only.** The user explicitly arms sharing. The payload auto-expires.
- **Requires device unlock.** `android:requireDeviceUnlock="true"` in the HCE service declaration. Contact data (PII) is never served to a locked phone.
- **Reads SharedPreferences on every APDU.** The OS can cold-start the HCE service; it never depends on in-memory state set by Flutter.
- **NFC off / no hardware.** The app degrades gracefully to QR-only mode. iPhone users always use QR.

---

## Build & Run

### Prerequisites

- Flutter (stable channel) — `flutter --version` to confirm
- Android Studio or VS Code with Flutter extension
- A physical Android device with NFC (emulator cannot test HCE)

### Run in debug mode

```bash
cd app
flutter pub get
flutter run
```

### Run tests

```bash
cd app
flutter test test/core/
```

### Run Kotlin unit tests

```bash
cd app/android
./gradlew test
```

### Build release APK

```bash
cd app
flutter build apk --release \
  --dart-define=TAPCARD_DOMAIN=tapcard.app \
  --dart-define=ADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXX~XXXXXXXXXX \
  --dart-define=NATIVE_AD_UNIT_ID=ca-app-pub-XXXXXXXXXXXX/XXXXXXXXXX
```

---

## Configuration

All environment-specific values are injected at build time via `--dart-define`. Nothing is hardcoded.

| Variable | Description | Dev default |
|---|---|---|
| `TAPCARD_DOMAIN` | Decoder page domain | `localhost:8080` |
| `ADMOB_APP_ID` | AdMob application ID | AdMob test ID |
| `NATIVE_AD_UNIT_ID` | Native ad unit for share screen | AdMob test unit |

The AdMob App ID is also set in `android/app/build.gradle.kts` via `manifestPlaceholders` for the `AndroidManifest.xml` `<meta-data>` entry. Update both when switching from test to production IDs.

---

## Design System

TapCard uses a **Soft Brutalist / Organic Minimal** design language. Clean, weighty, and tactile — like a well-printed business card.

| Token | Value | Use |
|---|---|---|
| `bgPrimary` | `#0E0E0E` | All screen backgrounds |
| `bgSecondary` | `#161616` | Card surfaces |
| `bgTertiary` | `#1F1F1F` | Input fills, elevated surfaces |
| `textPrimary` | `#F2F0EC` | Headings, active labels |
| `textSecondary` | `#9E9B96` | Body copy, detail rows |
| `accent` | `#E8E0D4` | Sparingly — one accent element per screen max |

Fonts: **Syne** (headings) · **DM Sans** (body) · **DM Mono** (numbers, codes)

No glassmorphism. No gradients. No shimmer. No looping animations.

---

## Monetization

Free app. No paywall. No subscriptions.

1. **Web decoder page footer** — every tap recipient sees "Powered by TapCard · Get yours →". Drives organic installs.
2. **AdMob native ad** — shown once, 420ms after a successful tap, auto-dismisses after 3 seconds. Never during arming. Never a banner.

---

## Build Status

| Phase | Status | What |
|---|---|---|
| Phase 1 — Core plumbing | ✅ Complete | Flutter scaffold, data layer, Kotlin HCE, platform channel |
| Phase 2 — Web decoder | 🔲 Next | `web/index.html`, Netlify deploy, end-to-end tap test |
| Phase 3 — App UI | 🔲 Pending | All 4 screens built and animated |
| Phase 4 — Widget + hardening | 🔲 Pending | Glance widget, AdMob integration, OEM test matrix |

---

## Privacy

- No user accounts
- No backend server
- No database
- No analytics on the decoder page
- No cookies
- Contact data is decoded entirely in the receiver's browser from the URL fragment — it never reaches any server
- Photo field is app-side display only — never included in the share URL

---

## License

Private repository. All rights reserved.
