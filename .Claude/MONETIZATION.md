# TapCard — Monetization Specification
> Free utility. Zero paywalls. Zero user billing. Revenue from two non-obstructive placements.

---

## Revenue Model

### Stream 1 — Web Decoder Page Footer (always-on)

**What it is:** The static page that every tap recipient sees shows a branded footer.

**Placement:**
```
┌─────────────────────────────┐
│  [Contact Card]             │
│                             │
│  [Save Contact button]      │
│                             │
│  ─────────────────────────  │
│  Powered by TapCard         │
│  Share your contact         │ ← this section
│  with a tap. Free. →        │
└─────────────────────────────┘
```

**Implementation:**
- Static HTML in `web/index.html`.
- The footer link points to the Play Store listing (or a landing page pre-launch).
- No analytics script, no cookies, no tracking on the receiver's page (privacy principle).
- The footer is part of the HTML — not injected by a third-party ad network.

**Why this works:** Every tap = one impression from a person who has never heard of TapCard, at the exact moment they are impressed by the product. The CTA is perfectly timed. This drives organic installs without spending on acquisition.

**Revenue mechanism:** Indirect. Drives installs → ad revenue from more daily active users.

---

### Stream 2 — AdMob Native Ad (post-share only)

**What it is:** A single native ad card shown on the share screen after a successful tap.

**SDK:** Google AdMob (latest — fetch from pub.dev at build time, never hardcode version).

**Ad format:** Native Ad (NOT banner, NOT interstitial, NOT rewarded video).

**Unit ID:** Configured in `core/constants.dart` via `--dart-define`. Never hardcoded.

**Placement rules (non-negotiable):**
1. Shown ONLY after a confirmed successful tap — never during arming, never in idle state.
2. Appears 420ms after the success state is confirmed (after the checkmark animation completes).
3. Auto-dismisses after 3 seconds if the user does not interact.
4. User can swipe the card down to dismiss immediately.
5. Screen resets to idle at 4 seconds regardless of ad state.
6. ONE ad per share event. No frequency cap needed — natural rate-limiting by usage.

**Visual treatment:**
- The native ad card uses `bgSecondary` (`#161616`) as its background.
- Ad content (headline, body, CTA, icon) is styled to match the app's `AppTypography` and `AppColours`.
- A single line `label`-style text "SPONSORED" in `textTertiary` appears above the card.
- No border, no shadow, no colour accent on the ad card.
- The card slides in from the bottom (Y+20 → Y+0, opacity 0→1, 280ms `easeOutCubic`).
- It slides out downward when dismissed (Y+0 → Y+20, opacity 1→0, 200ms).

**Admob native ad widget structure:**
```dart
/// NativeAdCard — renders a single AdMob native ad in the app's visual language.
/// Only used on the share success screen. Shown post-tap, auto-dismissed after 3s.
/// See .claude/MONETIZATION.md for full placement rules.
class NativeAdCard extends StatelessWidget {
  final NativeAd ad;
  // ... styled wrapper using AppColours, AppTypography
}
```

---

## Implementation Checklist

### Phase 4 (Widget + Hardening session)

**AdMob setup:**
- [ ] Add `google_mobile_ads` package (fetch latest version from pub.dev)
- [ ] Add AdMob App ID to `AndroidManifest.xml` via `--dart-define`
- [ ] Create native ad unit in AdMob console
- [ ] Implement `NativeAdManager` provider (Riverpod) — loads next ad in background after each share
- [ ] Implement `NativeAdCard` widget with app visual language
- [ ] Wire into share screen success state with 420ms delay
- [ ] Test: ad does not appear if no ad loaded (graceful fallback — screen resets normally)
- [ ] Test: ad auto-dismisses at 3s
- [ ] Test: user swipe-dismiss works

**Web page footer:**
- [ ] Add footer HTML to `web/index.html`
- [ ] Footer link points to Play Store URL (or `#` placeholder pre-launch)
- [ ] Verify footer is visible on mobile viewport without scrolling if card is short

---

## What Never Gets Added (scope boundary)

- No ad in onboarding
- No ad on the card editor screen
- No ad in the QR panel
- No interstitial ad that covers the full screen
- No banner ad anywhere
- No "remove ads" IAP (MVP — if this is added in v2, it is a one-time purchase, not a subscription)
- No rewarded video in MVP
- No sponsored "featured" cards in MVP
- No user data sold or shared with ad networks beyond what AdMob SDK does by default (review AdMob data disclosure for Play Store listing)

---

## Play Store Listing Notes

- Data safety section: must disclose AdMob data collection.
- AdMob requires `<meta-data>` in manifest for App ID.
- Test with `ca-app-pub-3940256099942544/2247696110` (AdMob test native ad unit ID) during development. Replace with real unit ID before release.
