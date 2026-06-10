# TapCard — Phase 2 Handover
> Read this at the start of the next session BEFORE touching any code.
> It records every decision made, every constraint hit, and exactly where to pick up.

---

## Session Summary

**Date:** 2026-06-09
**Phase completed:** Phase 1 — Full (Flutter scaffold + data layer + Kotlin native layer + platform channel)
**Status:** All Phase 1 items done. Tests green. Analyze clean.
**Next phase:** Phase 2 — Web decoder page + Netlify deploy.

---

## What Was Built Across Both Phase 1 Sessions

### Flutter side (`app/lib/`)

```
app/lib/
├── main.dart                              ← Hive init, ProviderScope, MaterialApp.router
├── core/
│   ├── tokens.dart                        ← AppTokens (spacing, radius, durations, curves)
│   ├── colours.dart                       ← AppColours (full palette from UI_DIRECTION.md)
│   ├── typography.dart                    ← AppTypography (Syne / DM Sans / DM Mono)
│   ├── constants.dart                     ← domain, channel names, box names, route paths
│   ├── router.dart                        ← go_router with 4 stub screens
│   ├── vcard_builder.dart                 ← vCard 3.0 builder, correct escape order ✓
│   └── url_codec.dart                     ← base64url encode/decode + 1200-char guard ✓
├── data/
│   ├── models/contact_card.dart           ← ContactCard + manual Hive TypeAdapter (typeId 0)
│   └── repositories/card_repository.dart  ← single-card Hive repository
├── features/                              ← ALL STUBS — built in Phase 3
│   ├── splash/splash_screen.dart
│   ├── onboarding/onboarding_screen.dart
│   ├── card_editor/card_editor_screen.dart
│   └── share/share_screen.dart
└── platform/
    └── nfc_channel.dart                   ← typed MethodChannel wrapper ✓
```

### Android native side (`app/android/`)

```
app/android/app/src/main/
├── AndroidManifest.xml                    ← NFC uses-feature, NFC permission, HCE service entry, AdMob meta-data
├── kotlin/com/tapcard/tapcard/
│   ├── MainActivity.kt                    ← registers NfcPlugin in configureFlutterEngine
│   ├── NdefApduProcessor.kt               ← pure APDU state machine (no Android deps, testable)
│   ├── NdefHostApduService.kt             ← thin HCE wrapper, delegates to NdefApduProcessor
│   └── NfcPlugin.kt                       ← tapcard/nfc MethodChannel handler
└── res/
    ├── values/strings.xml                 ← service_name = "TapCard NFC"
    └── xml/apduservice.xml                ← HCE AID D2760000850101, requireDeviceUnlock=true
```

### Kotlin tests

```
app/android/app/src/test/kotlin/com/tapcard/tapcard/
└── NdefApduProcessorTest.kt               ← 20 JUnit tests (no Android deps, runs with plain JUnit)
```

### Test / analysis status

- `flutter test test/core/` → **37/37 passing** (vcard_builder: 21, url_codec: 16)
- `flutter analyze` → **0 issues**
- Kotlin APDU tests: written and structured for plain JUnit — run with `./gradlew test` in `app/android/`

---

## Critical Package Constraints (DO NOT CHANGE)

The Flutter SDK on this machine pins `meta` at `1.17.0` via `flutter_test`. The following are intentionally pinned:

| Package | Pinned version | Why |
|---|---|---|
| `flutter_riverpod` | `^2.6.1` | 3.x needs `meta ^1.18.0` |
| `riverpod_annotation` | `^2.6.1` | Same chain |
| `flutter_native_splash` | `^2.3.13` | 2.4.x needs `meta ^1.18.0` |

**No code generation.** `hive_generator`, `riverpod_generator`, `build_runner` are NOT installed — all conflict via `meta`. Hive TypeAdapter is hand-written. Riverpod providers are written manually (no `@riverpod` annotations).

---

## Architecture Decisions (Frozen)

1. **Package name:** `com.tapcard.tapcard` (not `com.tapcard.app` — the handover template was wrong)
2. **Kotlin files at:** `app/android/app/src/main/kotlin/com/tapcard/tapcard/`
3. **Hive TypeAdapter field indices — never reorder:**
   - `0` → `fullName`, `1` → `cellPhone`, `2` → `email`, `3` → `company`
   - `4` → `jobTitle`, `5` → `note`, `6` → `photoPath`
4. **vCard escape order (load-bearing):** backslash → semicolon → comma → strip `\r` → replace `\n`
5. **URL codec:** base64url, no padding, 1200-char hard limit. Returns sealed `EncodeSuccess` / `EncodeTooLong`.
6. **APDU state machine split:** `NdefApduProcessor.kt` holds all pure logic; `NdefHostApduService.kt` is the thin Android wrapper. Never merge them back.
7. **SharedPreferences keys** (frozen — shared between `NdefHostApduService` and `NfcPlugin`):
   - `PREFS_NAME = "tapcard_nfc"`, `KEY_NDEF_URL`, `KEY_IS_ARMED`, `KEY_EXPIRES_AT_MS`
8. **AdMob placeholder:** `manifestPlaceholders["ADMOB_APP_ID"]` in `build.gradle.kts` — set to the AdMob test ID. Replace with real ID before production build.
9. **minSdk = 23** (set in `build.gradle.kts` — HCE requires API 19+; 23 is the right floor)
10. **Providers location:** `lib/core/providers/` — directory exists, no files yet. Providers for `CardRepository`, `NfcChannel`, and arm state go here.

---

## What To Build Next — Phase 2: Web Decoder Page

The web page is the missing half of the tap experience. Without it, the receiver's phone opens a URL that returns 404. This phase has no Flutter changes — it is pure HTML/CSS/JS + Netlify deployment.

**Deliverable:** a single `web/index.html` page deployed to Netlify at the production domain that:
1. Reads the `#fragment` from the URL
2. base64url-decodes it to a vCard 3.0 string
3. Parses the vCard fields
4. Renders a premium contact card matching the design in `.claude/UI_DIRECTION.md §Web Decoder Page Direction`
5. Provides a "Save Contact" button that triggers a `.vcf` download
6. Shows a graceful error state if the fragment is missing or corrupt (never a blank page)
7. Has a "Powered by TapCard · Get yours →" footer that drives installs

---

### Step-by-Step Build Order

#### Step 1 — Create `web/` directory and `netlify.toml`

```
web/
├── index.html     ← the entire page (< 15KB uncompressed)
└── netlify.toml   ← build config + redirect rules
```

`netlify.toml` must include:
```toml
[[redirects]]
  from = "/*"
  to = "/index.html"
  status = 200
```
This ensures deep-links (`https://domain/#fragment`) always serve `index.html`.

---

#### Step 2 — `web/index.html` — full specification

**Hard constraints (from CODE_STANDARDS.md and UI_DIRECTION.md):**
- Vanilla only — no frameworks, no npm, no build step.
- Total page weight: < 15KB uncompressed (HTML + CSS + JS all inline or in one `<script>` tag).
- No external fonts at runtime. System font stack: `-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`
- No Google Fonts, no CDN resources, no external scripts of any kind.
- `'use strict'` at top of JS. No `var`. Only `const`/`let`.
- Accessibility: semantic HTML, `aria-label` on interactive elements, contrast ≥ 4.5:1.
- Mobile-first layout. Centred vertically and horizontally, 100vh.
- No cookies, no localStorage, no analytics, no tracking of any kind.

**Visual spec (from UI_DIRECTION.md §Web Decoder Page Direction):**

```
Background:   #0E0E0E
Card surface: #161616,  border-radius: 20px,  max-width: 380px,  centred
Name:         28px, font-weight 600, color #F2F0EC
Details:      15px, color #9E9B96. Phone: monospace font.
"Save Contact" button:
  - full-width inside card
  - background: #1F1F1F
  - color: #F2F0EC
  - font-size: 14px
  - border-radius: 12px
  - height: 52px
  - no gradient, no shadow
  - hover: background #2A2A2A
Footer:
  - "Powered by TapCard · Get yours →"
  - 11px, color #5C5A57
  - centred below card
  - "Get yours →" is a link, color #9E9B96 with underline
```

**Layout structure (from top to bottom inside the card):**
```
[Full Name]           ← name, 28px, #F2F0EC
[Job Title @ Company] ← if present, 14px, #9E9B96
──────────────────────
[Phone number]        ← 15px, monospace, #9E9B96
[Email address]       ← 15px, #9E9B96
[Note]                ← if present, 13px, italic, #5C5A57
──────────────────────
[  Save Contact  ]    ← button, full-width
```

**JavaScript logic:**

```js
// 1. Read fragment
const fragment = window.location.hash.slice(1); // remove leading '#'
if (!fragment) { showError('No contact card found.'); return; }

// 2. base64url decode (RFC 4648 §5 — URL-safe alphabet, no padding)
//    Replace '-' with '+', '_' with '/', re-add padding, atob()
function base64urlDecode(str) {
  const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
  const padded = base64 + '=='.slice(0, (4 - base64.length % 4) % 4);
  return decodeURIComponent(
    atob(padded)
      .split('')
      .map(c => '%' + c.charCodeAt(0).toString(16).padStart(2, '0'))
      .join('')
  );
}

// 3. Parse vCard 3.0 fields
//    Keys to parse: FN, TEL, EMAIL, ORG, TITLE, NOTE
//    Handle TYPE qualifiers in TEL: TEL;TYPE=CELL, TEL;TYPE=WORK
//    Unescape: \\→\  \;→;  \,→,  \n→newline

// 4. Render card with parsed fields

// 5. Build .vcf file for download
//    Reconstruct a valid vCard 3.0 string from parsed fields
//    blob URL → <a download="contact.vcf"> → trigger click

// 6. Error state: friendly message, no JS error, no blank page
```

**Error state (fragment missing or corrupt):**
```html
<div class="error">
  <p>This contact card link is invalid or has expired.</p>
  <a href="https://tapcard.app">Get TapCard →</a>
</div>
```

---

#### Step 3 — Domain configuration

The domain is injected into the Flutter app via `--dart-define=TAPCARD_DOMAIN=yourdomain.com` at build time (see `AppConstants.domain` in `lib/core/constants.dart`). For Phase 2 testing you can use the Netlify preview URL — just point `TAPCARD_DOMAIN` at it.

**Do not hardcode the domain in `index.html`** — the page has no domain dependency; it only reads the URL fragment. The "Get yours →" footer link can point to your Netlify domain or a placeholder.

---

#### Step 4 — End-to-end test

Before marking Phase 2 complete:
1. Build a test vCard string manually.
2. Run it through `url_codec.dart` (or replicate the base64url logic in a scratch JS snippet).
3. Navigate to `https://yournetlifydomain/#<encoded>` in a real mobile browser.
4. Verify: name, phone, email render correctly.
5. Tap "Save Contact" — verify `.vcf` downloads and imports correctly into Contacts on both Android and iOS.
6. Navigate to `https://yournetlifydomain/#` (empty fragment) — verify error state, no blank page.
7. Navigate to `https://yournetlifydomain/#!!!INVALID!!!` (corrupt fragment) — verify error state.

---

## Session Startup Checklist for Phase 2 Session

```
1. Read .claude/PROJECT.md               ← single source of truth
2. Read .claude/NFC_SPEC.md §vCard 3.0  ← escaping rules are load-bearing for the parser
3. Read .claude/UI_DIRECTION.md          ← §Web Decoder Page Direction
4. Read .claude/CODE_STANDARDS.md        ← §HTML/JS Standards
5. Read this file (HANDOVER_PHASE2.md)
6. Run: cd app && flutter analyze        ← confirm still clean before touching anything
7. Run: cd app && flutter test test/core/ ← confirm 37/37 still passing
```

---

## Known Issues / Watch Out For

- **`app/lib/core/providers/` is empty.** Riverpod providers for `CardRepository`, `NfcChannel`, and arm state have not been written yet. They are needed in Phase 3, not Phase 2.
- **`flutter_native_splash` is installed but not configured.** A `flutter_native_splash.yaml` at `app/` root needs to be created and `dart run flutter_native_splash:create` run. Requires the wordmark SVG asset. Do in Phase 3.
- **`widget_channel.dart` does not exist yet.** Needed in Phase 4.
- **`TapCardWidget.kt` (Glance widget) does not exist yet.** Needed in Phase 4.
- **vCard parser in JS** — the most common bug is double-unescaping. Parse fields by splitting on CRLF line endings first, then handle TYPE= qualifiers, then unescape field values. Never unescape before splitting lines.
- **iOS `.vcf` download** — `<a download="contact.vcf" href="data:text/vcard;...">` works on Android Chrome but iOS Safari requires `text/x-vcard` MIME type and may open inline instead of downloading. Test on real iPhone, not just desktop browser.
- **Fragment encoding** — the `#` character is never sent to the server; it lives only in the browser. The Netlify redirect rule is only needed so that visiting the bare domain (or a path) returns `index.html`. The fragment itself requires no server-side handling.

---

## File Tree Snapshot (end of Phase 1)

```
tapcard/
├── .claude/
│   ├── PROJECT.md
│   ├── CODE_STANDARDS.md
│   ├── NFC_SPEC.md
│   ├── PLATFORM_CHANNEL.md
│   ├── UI_DIRECTION.md
│   ├── MONETIZATION.md
│   ├── HANDOVER_PHASE1.md     ← previous session handover
│   └── HANDOVER_PHASE2.md     ← this file
└── app/
    ├── pubspec.yaml
    ├── lib/                   ← see tree above
    ├── test/core/             ← 37 tests passing
    └── android/app/src/main/
        ├── AndroidManifest.xml
        ├── kotlin/com/tapcard/tapcard/   ← 4 Kotlin files
        └── res/values/strings.xml + res/xml/apduservice.xml

web/                           ← DOES NOT EXIST YET — build this in Phase 2
```
