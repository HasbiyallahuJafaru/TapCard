# TapCard — UI Direction
> Governs every visual decision in the Flutter app and the web decoder page.
> Claude Code reads this before writing a single widget.

---

## Aesthetic Direction: Soft Brutalist / Organic Minimal

Not a predefined template. A custom direction synthesised for TapCard.

**The design language:** Clean, weighty, and tactile. Like a well-printed business card — understated but deliberate. Dark surfaces with material texture, not glass or neon. Typography does the heavy lifting. Motion is subtle and physical, not theatrical. The app should feel like a premium physical object, not a tech product.

**Reference mood:** Teenage Engineering product UI · Linear.app · Vercel dashboard · A high-end letterpress business card.

**What it is NOT:**
- Not glassmorphism (no frosted blur panels)
- Not dark luxury (no gold accents, no Playfair Display)
- Not gradient-heavy (zero decorative gradients)
- Not neon / glow / LED aesthetic
- Not "AI-generated card app" look (no animated shimmer rings, no orbiting particles, no morphing blobs)
- Not playful / rounded / bubbly

---

## Colour System

### Palette

```dart
class AppColours {
  // Backgrounds
  static const bgPrimary   = Color(0xFF0E0E0E); // near-black, warm-neutral
  static const bgSecondary = Color(0xFF161616); // card surface
  static const bgTertiary  = Color(0xFF1F1F1F); // elevated surface, input fills

  // Text
  static const textPrimary   = Color(0xFFF2F0EC); // warm off-white (not pure white)
  static const textSecondary = Color(0xFF9E9B96); // 60% muted warm grey
  static const textTertiary  = Color(0xFF5C5A57); // 35% captions, placeholders
  static const textDisabled  = Color(0xFF333230); // 20% inactive

  // Accent — single, restrained
  static const accent        = Color(0xFFE8E0D4); // warm parchment — used sparingly
  static const accentMuted   = Color(0xFF3D3A36); // accent at surface level

  // Functional
  static const success       = Color(0xFF4CAF50); // standard green, not lime
  static const error         = Color(0xFFE57373); // muted red, not bright
  static const divider       = Color(0xFF232320); // barely visible

  // NFC state colours
  static const nfcIdle       = Color(0xFF2A2A2A); // dormant ring
  static const nfcArmed      = Color(0xFFF2F0EC); // active — same as textPrimary (glows)
  static const nfcSuccess    = Color(0xFF4CAF50); // tap confirmed
}
```

**60/30/10 rule:**
- 60% → `bgPrimary` / `bgSecondary` — dominates every screen
- 30% → `bgTertiary` / surfaces / typography at 60%
- 10% → `accent`, functional colours, NFC state indicators

---

## Typography

### Font Pairing

```dart
// Display / heading: Syne — geometric, slightly quirky, strong personality
// Body / UI: DM Sans — clean, readable, neutral
// Mono (data, codes, phone numbers): DM Mono

import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextStyle display({required double size, Color? color, double? letterSpacing}) =>
    GoogleFonts.syne(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color ?? AppColours.textPrimary,
      letterSpacing: letterSpacing ?? -0.03 * size, // tight on display
      height: 1.1,
    );

  static TextStyle title({required double size, Color? color}) =>
    GoogleFonts.syne(
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: color ?? AppColours.textPrimary,
      letterSpacing: -0.02 * size,
      height: 1.2,
    );

  static TextStyle body({required double size, Color? color}) =>
    GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColours.textSecondary,
      letterSpacing: 0.01 * size,
      height: 1.55,
    );

  static TextStyle bodyMedium({required double size, Color? color}) =>
    GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? AppColours.textPrimary,
      letterSpacing: 0,
      height: 1.4,
    );

  static TextStyle label({required double size, Color? color, bool uppercase = true}) =>
    GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color ?? AppColours.textTertiary,
      letterSpacing: uppercase ? 0.12 * size : 0.02 * size,
      height: 1.2,
    ).copyWith(
      textBaseline: TextBaseline.alphabetic,
    );

  static TextStyle mono({required double size, Color? color}) =>
    GoogleFonts.dmMono(
      fontSize: size,
      fontWeight: FontWeight.w400,
      color: color ?? AppColours.textPrimary,
      letterSpacing: 0,
      height: 1.4,
    );
}
```

### Usage Map
| Element | Style | Size |
|---|---|---|
| App name / hero text | `display` | 36–44sp |
| Screen titles | `title` | 24–28sp |
| Section headers | `title` | 18sp |
| Body text | `body` | 15sp |
| Card / list primary | `bodyMedium` | 15–17sp |
| Card / list secondary | `body` | 13sp |
| Labels, overlines | `label` | 10–11sp uppercase |
| Phone number display | `mono` | 17sp |
| Countdown timer | `mono` | 32sp |

---

## Motion System

### Philosophy
- **Subtle and physical.** Like a heavy object settling, not a cartoon.
- **Purpose over decoration.** Every animation communicates a state change.
- **No looping ambient animations.** Nothing moves unless triggered by a user action or a state change.
- **No shimmer rings. No pulsing blobs. No orbiting particles.**

### Duration Tokens
```dart
// Inherit from AppTokens — confirm these are set
static const Duration tapFeedback = Duration(milliseconds: 120); // immediate
static const Duration stateChange = Duration(milliseconds: 280); // mode switch
static const Duration entrance    = Duration(milliseconds: 420); // screen entry
static const Duration nfcArm      = Duration(milliseconds: 600); // NFC arm animation
```

### Curves
```dart
static const Curve snap    = Curves.easeOutCubic;   // snappy UI responses
static const Curve settle  = Curves.easeInOutCubic; // state changes
static const Curve spring  = Curves.elasticOut;     // arm/disarm ring
static const Curve entrance = Curves.easeOutQuart;  // screen entrances
```

### Allowed Animations (exhaustive list for MVP)

1. **Entrance stagger** — every screen's elements fade+slide in with 60ms stagger. Translate Y: 12px → 0, opacity 0 → 1. Not more dramatic than this.
2. **Tap feedback** — `PressableWidget`: scale 1.0 → 0.97 on press, spring back on release. Subtle. No color flash.
3. **NFC ring expand** — the share screen's circular ring expands from r=80 to r=120 over 600ms with `elasticOut` when armed. Contracts on disarm. This is the ONE expressive animation in the app.
4. **Countdown** — the ring has a stroke that drains like a clock over 60 seconds. `AnimatedBuilder` + `CustomPainter`. No pulsing.
5. **State text fade** — "Tap to Share" / "Ready" / "Shared!" text crossfades (opacity only, no slide) over 280ms.
6. **Success check** — a simple `DrawPath` animation of a checkmark. Duration: 400ms. No confetti, no particles for MVP.
7. **QR reveal** — slides up from below the fold, 420ms `easeOutQuart`. Dismissed with a downward swipe.
8. **Card editor field focus** — label floats up (standard FloatingLabelField behaviour). Nothing custom needed.
9. **Page transitions** — `FadeScaleRoute`: fade + scale 0.96→1.0. Not a full slide. Feels native but premium.

**Explicitly banned animations:**
- Shimmer rings or glow pulsing around the NFC area
- Particle effects or confetti (MVP)
- Morphing shapes / blobs
- Any looping idle animation
- "Wave" or "ripple" spread animations
- Lottie files depicting generic "connection" or "wireless" icons (use custom `CustomPainter`)

---

## Screen-by-Screen Direction

### Splash Screen (two-stage)

TapCard uses a two-stage splash approach — standard on Android for premium feel:

**Stage 1 — Native OS splash (instant, zero Flutter overhead)**
- Configured via `flutter_native_splash` package.
- Background: `#0E0E0E` (matches `bgPrimary` exactly — no flash of white).
- Centre: the TapCard wordmark as a static SVG asset — white on dark. No icon, no logomark. The name IS the identity.
- This screen appears before Flutter engine initialises. It is purely static.
- `flutter_native_splash.yaml` config: `color: "#0E0E0E"`, `image: assets/splash/wordmark.svg`, `android_12` settings included.

**Stage 2 — Animated Flutter splash (300–700ms total)**
This is a `SplashScreen` widget that replaces the native splash the moment Flutter is ready. It completes and navigates away before the user notices the handoff.

**Animation sequence:**

```
t=0ms    Screen starts: wordmark is already visible (matches native splash exactly)
t=0ms    Wordmark opacity: 0 — it fades IN to create a seamless cross-fade from native
t=80ms   Wordmark fully visible (opacity 1.0, easeOutCubic)
t=180ms  Tagline fades in below wordmark: "tap. share. done."
         — DM Sans 13sp, textTertiary colour, letter-spacing 0.15em, uppercase
         — opacity 0 → 0.6, Y+4 → Y+0, 280ms easeOutCubic
t=500ms  Brief hold
t=600ms  Entire screen fades out (opacity 1 → 0, 200ms easeInCubic)
t=800ms  Navigate to: onboarding (first launch) OR share screen (returning user)
```

**Rules:**
- Total duration: 800ms maximum. Never longer.
- No logo animation — the wordmark does NOT scale, bounce, rotate, or morph.
- No background animation — solid `bgPrimary`, nothing moves behind the text.
- No loading indicator — this is a brand moment, not a loading screen.
- The tagline is the only motion after the wordmark settles.
- Wordmark font: `Syne 700`, 28sp, `textPrimary`, letter-spacing `-0.02em`.
- Tagline font: `DM Sans 500`, 12sp, `textTertiary`, letter-spacing `0.14em`, uppercase.
- Wordmark and tagline are centred, stacked vertically, gap: `AppTokens.sm` (8px).

**Navigation logic (inside SplashScreen):**
```dart
// During the hold period (t=500ms), determine destination:
final hasCard = await cardRepository.hasCard();
final isFirstLaunch = await prefsRepository.isFirstLaunch();

// Navigate at t=800ms:
if (isFirstLaunch || !hasCard) {
  context.go('/onboarding');
} else {
  context.go('/share');
}
```

**Implementation notes:**
- Use `flutter_animate` for the sequence — clean, composable, no manual `AnimationController`.
- The native splash config (`flutter_native_splash`) must be run after any `flutter pub get`: `dart run flutter_native_splash:create`.
- `SplashScreen` is a `StatefulWidget` — it initiates async checks during the hold window.
- No `Future.delayed` hacks. Use `flutter_animate`'s `delay` + callback for the navigation trigger.

---

### Onboarding (2 screens)

**Screen 1 — Welcome**
- Full dark background `bgPrimary`
- Large `display` text, left-aligned: "Share your contact. Just tap."
- Below: `body` text explanation, muted. Max 2 lines.
- Single CTA button at bottom: outlined style (1px `divider`-coloured border, no fill, `textPrimary` label). Not a gradient button.
- No illustrations, no photos, no icons. Pure typography screen.
- Entrance: text staggered in from Y+12, opacity 0→1.

**Screen 2 — NFC Permission**
- Same dark background.
- Icon: a single custom SVG — two phones facing each other, minimal line art, `textTertiary` colour. Static, no animation.
- Explanation text + "Enable NFC" button (same outlined style).
- If NFC unavailable: different copy, QR-only mode explanation.

---

### Card Editor

- Standard scrollable screen with `bgPrimary` background.
- Each field: `FloatingLabelField` on `bgTertiary` fill, no border in idle state, 1px `accent` underline only on focus. Radius `radiusMd` (16).
- Field order: Full Name (required) → Phone (required) → Email → Company → Job Title → Note.
- "Required" fields marked with a small dot, not an asterisk.
- Save button: full-width, `bgTertiary` fill, `textPrimary` label. Rounded `radiusMd`. NOT a gradient button.
- Photo field: circular avatar slot, `bgTertiary` fill, tap opens image picker. Label: "PHOTO (OPTIONAL)" in `label` style. Photo stays in-app only — clear disclaimer below the field.
- URL length indicator: small progress bar at bottom of screen. Fills left-to-right as fields are filled. Colour: `success` when safe, `error` when approaching limit. Text: "123 / 1200 chars". `mono` style.

---

### Share Screen (core screen)

**Idle state:**
- Background: `bgPrimary`
- Centre: a circle, `bgTertiary` fill, 160px diameter. No shadow. This is the "tap zone" visual anchor.
- Inside circle: NFC icon (custom SVG, minimal) in `textTertiary`. Static.
- Below circle: `title` text "Tap to Share" in `textPrimary`.
- Below title: `body` text "Hold your phone still. Tap theirs to yours." in `textSecondary`.
- Bottom section: QR code toggle — small text button "Show QR Code" with a subtle underline. Tap reveals QR panel sliding up.
- Top right: settings/edit icon (takes to card editor).

**Armed state (after user taps the circle):**
- Circle ring animates to expanded size with `elasticOut`. Ring stroke becomes `nfcArmed` (warm off-white).
- Stroke drains as countdown progresses (custom `CustomPainter`).
- Centre text changes to countdown: `32` in `mono` 32sp. Cross-fades from icon.
- Title text changes to "Ready — Tap Phones Together".
- Tap anywhere outside the ring: disarm.

**Success state (tap detected):**
- Ring contracts to original size instantly (80ms `easeOutCubic`).
- Circle fill flashes to `success` green briefly (280ms), then back to `bgTertiary`.
- Checkmark draws inside circle (400ms `DrawPath`).
- Title text: "Shared!" — `success` colour.
- AdMob native ad card fades in below the circle, 420ms delay after success. Ad card has `bgSecondary` surface, matches app design. Auto-dismisses after 3s. User can swipe it away.
- Screen auto-resets to idle after 4s.

---

### QR Panel (bottom sheet, not a full screen)

- Slides up from bottom, 420ms `easeOutQuart`.
- `bgSecondary` background, `radiusLg` top corners only.
- QR code: white-background square, `radiusMd` corners, centred. Generous padding around QR.
- Below QR: "Scan with any camera" in `label` style.
- Below label: "Share link" text button — copies the share URL to clipboard.
- Drag handle at top. Can be swiped down to dismiss.

---

## Spacing & Layout Rules

- All values from `AppTokens`. No magic numbers in layout code.
- Screen horizontal padding: `AppTokens.lg` (24) on both sides.
- Card padding: `AppTokens.md` (16) all sides.
- Between sections: `AppTokens.xl` (32).
- Between related fields: `AppTokens.md` (16).
- Bottom padding above nav/buttons: `AppTokens.xxl` (48) minimum.
- Touch targets: minimum 48×48px (system requirement). Enforce without exception.

---

## Glance Widget Direction

- Size: standard 2×1 home widget (medium).
- Background: `bgSecondary` — matches app but distinct from other widgets.
- Content (idle): app name "TapCard" in `label` style (10sp uppercase) top left. Large NFC icon centred. "TAP TO SHARE" in `label` style below. All `textSecondary`.
- Content (armed): ring icon with stroke countdown. Countdown number in `mono`. "READY" label.
- Content (success): checkmark icon. "SHARED" label. Resets after 4s.
- No gradient, no photo, no colour blocks. Pure typography + icon.

---

## Web Decoder Page Direction

- Background: `#0E0E0E` — matches app.
- Card: `#161616` surface, `border-radius: 20px`, max-width 380px, centred.
- Typography: system font stack (no Google Fonts load for page speed): `-apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif`.
- Name: 28px, font-weight 600, `#F2F0EC`.
- Detail rows (phone, email, company): 15px, `#9E9B96`. Phone in monospace.
- "Save Contact" button: full-width, `#1F1F1F` background, `#F2F0EC` text, 14px, `border-radius: 12px`, 52px height. No gradient, no shadow. Hover: `#2A2A2A`.
- Footer: "Powered by TapCard · Get yours →" — 11px, `#5C5A57`, centred. Link: `#9E9B96` underline.
- Total page: < 15KB. No external JS. No tracking. No cookies.
- Mobile-first, 100vh centred layout.
