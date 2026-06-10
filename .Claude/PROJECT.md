# TapCard — Project Master Document
> Read this file at the start of every Claude Code session. It is the single source of truth.

---

## What This Is

TapCard is a free Android utility app. One job: tap your phone against any NFC-capable phone and the receiver gets your contact card — instantly, no app required on their side. QR code as universal fallback.

**Not a social app. Not a SaaS platform. A premium utility — as fast and silent as a tap.**

---

## Architecture in One Paragraph

The Flutter app stores one contact card locally (Hive). When the user arms sharing, a native Kotlin `HostApduService` emulates an NFC Type 4 Tag. The NDEF payload is a single URI record pointing to `https://<domain>/#<base64url(vCard)>`. The receiver's phone opens that URL in their browser; a static Netlify page decodes the fragment client-side and renders a premium contact card with a one-tap "Save Contact" button that downloads a `.vcf` file. The fragment never hits the server — the vCard is decoded entirely in the browser. A home-screen Glance widget arms NFC sharing without opening the app.

---

## Repository Layout

```
tapcard/
├── .claude/                        ← you are here
│   ├── PROJECT.md
│   ├── CODE_STANDARDS.md
│   ├── NFC_SPEC.md
│   ├── PLATFORM_CHANNEL.md
│   ├── UI_DIRECTION.md
│   └── MONETIZATION.md
├── app/                            ← Flutter project root
│   ├── lib/
│   │   ├── core/
│   │   │   ├── tokens.dart         ← AppTokens (spacing, radius, durations)
│   │   │   ├── typography.dart     ← AppTypography
│   │   │   ├── colours.dart        ← AppColours
│   │   │   ├── vcard_builder.dart  ← builds vCard 3.0 string from ContactCard model
│   │   │   └── url_codec.dart      ← base64url encode/decode + length guard
│   │   ├── data/
│   │   │   ├── models/contact_card.dart   ← Hive model
│   │   │   └── repositories/card_repository.dart
│   │   ├── features/
│   │   │   ├── onboarding/         ← first launch, NFC permission, NFC enabled check
│   │   │   ├── card_editor/        ← create/edit the single contact card
│   │   │   └── share/              ← NFC arm/disarm UI + QR code display
│   │   ├── platform/
│   │   │   ├── nfc_channel.dart    ← Flutter side of MethodChannel "tapcard/nfc"
│   │   │   └── widget_channel.dart ← Flutter side of MethodChannel "tapcard/widget"
│   │   └── main.dart
│   └── android/
│       └── app/src/main/kotlin/com/tapcard/app/
│           ├── MainActivity.kt
│           ├── NdefHostApduService.kt
│           ├── NfcPlugin.kt              ← MethodChannel handler
│           └── widget/
│               └── TapCardWidget.kt      ← Glance widget
└── web/                                  ← static decoder page
    ├── index.html
    └── netlify.toml
```

---

## Tech Stack

| Layer | Choice | Reason |
|---|---|---|
| UI | Flutter (latest stable) | hasbiy-flutter design system; plugin ecosystem |
| Local storage | Hive (latest) | fast, type-safe, zero setup |
| NFC HCE | Native Kotlin | no Flutter plugin does HCE reliably |
| Home widget | Glance (Jetpack) | modern Compose-based widget API |
| Platform bridge | Flutter MethodChannel | two channels: nfc, widget |
| Routing | go_router (latest) | declarative, deep-link-ready |
| QR | qr_flutter (latest) | check at build time |
| Ads | Google AdMob — native ads only | never banners |
| Splash screen | flutter_native_splash + custom animated Flutter screen | two-stage splash (see UI_DIRECTION.md) |
| Web page | Vanilla HTML/CSS/JS, Netlify | zero build step, <15KB total |

**Before pinning any package version: fetch the latest from pub.dev. Never use a version from memory.**

---

## Build Phases

### Phase 1 — Core plumbing (no UI polish)
- [ ] Flutter scaffold + Hive setup
- [ ] `flutter_native_splash` configured (static OS-level splash)
- [ ] `ContactCard` model with Hive adapter
- [ ] `vcard_builder.dart` with full escaping + golden tests
- [ ] `url_codec.dart` with length guard + tests
- [ ] Kotlin `NdefHostApduService` full APDU state machine
- [ ] `NfcPlugin.kt` MethodChannel handler
- [ ] `nfc_channel.dart` Flutter wrapper
- [ ] AndroidManifest wiring (HCE, NFC permissions, APDU service)
- [ ] `/graphify .` at session start

### Phase 2 — Web decoder page
- [ ] `web/index.html` — decode, render premium card, save .vcf
- [ ] Deploy to Netlify, lock domain
- [ ] End-to-end tap test: Android → iPhone, Android → Android

### Phase 3 — App UI
- [ ] Splash screen: `SplashScreen` widget with animated wordmark (see UI_DIRECTION.md)
- [ ] Onboarding flow (NFC check, permission)
- [ ] Card editor screen
- [ ] Share screen (idle / armed / success states)
- [ ] QR code screen
- [ ] UI_DIRECTION.md governs all visual decisions

### Phase 4 — Widget + hardening
- [ ] Glance widget (idle / armed / countdown states)
- [ ] `widget_channel.dart`
- [ ] AdMob native ad on share success screen
- [ ] Edge-case pass (see NFC_SPEC.md §Failure modes)
- [ ] graphify incremental rebuild
- [ ] OEM test matrix

---

## Critical Constraints

1. **No user accounts. No backend. No database.** Local-only. Full stop.
2. **No photo in the share URL payload.** Photo is app-side display only.
3. **Max encoded URL length: 1,200 characters.** Enforce in `url_codec.dart`. Warn user if optional fields push past limit.
4. **HCE requires screen on.** Require device unlock for sharing. Do not serve NDEF when disarmed.
5. **60-second auto-disarm.** Payload + arm flag + expiry timestamp stored in SharedPreferences. HCE service validates expiry on every SELECT command.
6. **QR is always visible alongside NFC.** Never NFC-only UI. iPhone fallback is mandatory.
7. **Admob native ads only.** No banners. One placement: post-share success screen. Below the fold. Never interrupts the tap flow.

---

## Monetization Model

1. **Web decoder page:** "Powered by TapCard · Get yours →" footer. Always present. Drives organic installs.
2. **Post-share AdMob native ad:** single sponsored card shown after tap success. Auto-dismisses after 3s; user can dismiss sooner.
3. **No paywall. No subscriptions. No IAP in MVP.**

Full spec: `MONETIZATION.md`

---

## Session Startup Checklist (every session)

```bash
pip install graphifyy --break-system-packages
graphify claude install   # once per project
/graphify .               # at session start
```

Then read the relevant `.claude/` files for the phase being worked on. Never skip this.
