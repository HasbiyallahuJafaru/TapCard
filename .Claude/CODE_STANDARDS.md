# TapCard — Code Standards
> Non-negotiable. Applies to every file in this repo: Flutter, Kotlin, HTML, JS.

---

## Universal Quality Gate

Before marking any task complete, run this sequence in order:

1. **Stress test** — edge cases (null fields, empty strings, max-length inputs, Unicode names, special characters in vCard fields, NFC off, no NFC hardware, screen locked, process killed mid-arm)
2. **Integration check** — no conflicts with existing code, no regressions in vcard_builder / url_codec / APDU service
3. **Run the code** — actually execute it; deep static analysis
4. **Auto-fix** — fix obvious bugs and report them explicitly
5. **Escalate** — critical architectural issues are flagged immediately, not silently worked around
6. **Best practices** — applied without being asked

**Platform-specific:**
- Flutter: `flutter analyze` + `flutter test` must pass clean
- Kotlin: lint + compile clean, no suppressed warnings without explanation
- HTML/JS: validate markup, check JS errors in console

---

## File Rules

- **300-line cap per file.** If a file approaches 300 lines, split it before continuing.
- **File-level description comment** at the top of every file — one or two sentences explaining what this file is and what it is not.
- **Full doc comments on every public symbol** (Dart: `///`, Kotlin: `/** */`, JS: `/** */`). Parameters, return values, and thrown exceptions documented.
- **Inline comments on every non-obvious block.** If you had to think about it, comment it.
- **No undocumented code shipped.** Zero exceptions.

---

## Dart / Flutter Standards

```dart
// ✅ Always
/// Brief description of what this class/function does.
///
/// [param] — what it is and valid range
/// Returns — what it returns
/// Throws [StateError] if — when
class MyClass { ... }

// ✅ Explicit logic over clever one-liners
// Bad:
final result = items.fold<int>(0, (a, b) => a + b.value * (b.active ? 1 : 0));
// Good:
int total = 0;
for (final item in items) {
  if (item.active) total += item.value;
}

// ✅ Self-documenting names — no abbreviations
// Bad: final vcStr = buildVc(cd);
// Good: final vCardString = buildVCard(contactCard);

// ✅ Never use raw GestureDetector or InkWell on anything tappable
// Use PressableWidget from the design system. Always.

// ✅ Never use Image.network() — always CachedNetworkImage with shimmer

// ✅ No default AppBar, no default Card(), no unstyled showDialog

// ✅ All spacing from AppTokens — no magic numbers inline
//    Bad: SizedBox(height: 16)
//    Good: SizedBox(height: AppTokens.md)
```

### State Management
- Riverpod (latest) for all app state.
- No `setState` outside of trivial local animation controllers.
- Providers in `lib/core/providers/` with full doc comments.

### Error Handling
- Never swallow exceptions silently.
- All caught errors: log using `debugPrint` in debug builds only. Use `if (kDebugMode)` guard — nothing logs in release.
- Surface errors to user via `InlineToast` (never a raw `ScaffoldMessenger.showSnackBar`).
- Local IO operations (Hive reads/writes): explicit `try/catch` with typed exceptions.
- No error reporting SDK. No external telemetry. No network calls from error handlers.

### Testing
- Every function in `vcard_builder.dart` has a golden test.
- Every function in `url_codec.dart` has a golden test including edge cases: empty string, max length, Unicode, special characters (`;`, `,`, `\n`, `\r`, `\`).
- APDU state machine tested with mock byte sequences.
- Minimum: test what can silently fail.

---

## Kotlin Standards

```kotlin
/**
 * Brief class description.
 *
 * @param context Application context — must not be Activity context
 */
class NdefHostApduService(context: Context) {

    /**
     * Handles an incoming APDU command byte array.
     *
     * @param commandApdu Raw APDU bytes from the reader device
     * @param extras Optional extras bundle from the system
     * @return Response APDU bytes, or SW_UNKNOWN on unrecognised command
     */
    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray { ... }
}
```

- Kotlin idioms over Java-style code (data classes, sealed classes, extension functions, `when` over `if-else` chains).
- All byte arrays: comment with hex representation for readability.
- `SharedPreferences` key constants defined in a `companion object` — never inline strings.
- No `!!` (force-unwrap) without an explicit comment explaining why it is guaranteed safe.
- Coroutines for async work — no `Thread`, no `AsyncTask`.

---

## HTML / JS Standards (web decoder page)

- Vanilla only — no frameworks, no npm, no build step.
- Total page weight: < 15KB uncompressed (HTML + CSS + JS inline or linked).
- No external fonts loaded at runtime (system font stack only, or one Google Font preload max).
- Accessibility: semantic HTML, `aria-label` on interactive elements, contrast ratio ≥ 4.5:1.
- JS: `'use strict'`, no `var` (only `const`/`let`), explicit null checks before DOM access.
- Error state: if fragment is missing/corrupt, show friendly message — never a blank page or JS error.

---

## Version Policy

**Never hardcode package versions from memory.**

Before adding any dependency:
1. Check pub.dev (Dart) or Maven Central / GitHub (Kotlin/Gradle) for the latest stable version.
2. Pin to that version.
3. Add a comment: `// pinned YYYY-MM-DD — check for updates before next major session`

Same rule applies to AdMob SDK, Glance version, NFC library versions.

---

## Logging Policy

No error tracking SDK. No Sentry. No Firebase Crashlytics. No external telemetry of any kind.

```dart
// ✅ Debug logging — always guarded
if (kDebugMode) {
  debugPrint('[NfcChannel] arm failed: ${e.code}');
}

// ❌ Never
print('something happened'); // unguarded, leaks to release
log('error', error: e);      // unguarded dart:developer log
```

- `debugPrint` is automatically a no-op in release builds when wrapped in `kDebugMode`.
- Log messages must be prefixed with the class name: `[ClassName]`.
- Never log field values from `ContactCard` — names, phone numbers, emails are PII.
- Log: error codes, state transitions, method names, byte lengths. Not content.

---

## What Never Ships

- `print()` statements anywhere (use `debugPrint` inside `kDebugMode` guard)
- Unguarded `debugPrint` calls (must be inside `if (kDebugMode)`)
- Hardcoded domain/URL strings outside `core/constants.dart`
- Magic numbers (use `AppTokens`)
- Suppressed lint warnings without explanation comment
- A screen without entrance animations
- A tappable without a haptic response
- Grey `BoxShadow` anywhere
- `Image.network()` anywhere
- Raw `GestureDetector` or `InkWell` on a visible UI element
- A file without a top-level description comment
- Any external telemetry, analytics SDK, or error reporting SDK
