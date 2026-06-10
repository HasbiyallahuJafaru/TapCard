# TapCard — Platform Channel Contract
> This interface is frozen. Do not add, rename, or change method signatures without updating
> both the Kotlin handler (NfcPlugin.kt) and the Dart wrapper (nfc_channel.dart) together
> and incrementing the CHANNEL_VERSION constant in both files.

---

## Channel: `tapcard/nfc`

Handles all NFC HCE arming, disarming, and availability queries.

### CHANNEL_VERSION = 1

---

### Method: `setPayload`

Sets the NDEF URL payload in SharedPreferences. Does NOT arm sharing.
Must be called before `arm`. Safe to call multiple times.

**Dart call:**
```dart
await _channel.invokeMethod<bool>('setPayload', {'url': shareUrl});
```

**Kotlin signature:**
```kotlin
fun setPayload(url: String): Boolean
```

**Arguments:**
| Key | Type | Constraints |
|---|---|---|
| `url` | String | Must start with `https://`. Max 1,200 characters (enforced in Dart before calling). |

**Returns:** `true` if payload was stored successfully, `false` if SharedPreferences write failed.

**Errors:**
- `INVALID_URL` — URL does not start with `https://` or is empty.
- `PAYLOAD_TOO_LONG` — URL exceeds 1,200 characters (should be caught Dart-side first; Kotlin is a backstop).

---

### Method: `arm`

Arms the HCE service. Writes `is_armed = true` and `expires_at_ms = now + timeoutMs` to SharedPreferences. A payload must have been set via `setPayload` first.

**Dart call:**
```dart
final success = await _channel.invokeMethod<bool>('arm', {'timeoutSec': 60});
```

**Kotlin signature:**
```kotlin
fun arm(timeoutSec: Int): Boolean
```

**Arguments:**
| Key | Type | Default | Constraints |
|---|---|---|---|
| `timeoutSec` | Int | 60 | Range: 10–300. Values outside range are clamped. |

**Returns:** `true` if armed successfully.

**Errors:**
- `NO_PAYLOAD` — `setPayload` has not been called yet.
- `NFC_UNAVAILABLE` — device has no NFC hardware.
- `NFC_DISABLED` — NFC hardware exists but is turned off.

---

### Method: `disarm`

Manually disarms the HCE service before the timeout expires.

**Dart call:**
```dart
await _channel.invokeMethod<void>('disarm');
```

**Kotlin signature:**
```kotlin
fun disarm(): Unit
```

**Arguments:** none

**Returns:** void. Always succeeds (idempotent — safe to call when already disarmed).

---

### Method: `isNfcAvailable`

Returns the current NFC hardware and software state.

**Dart call:**
```dart
final result = await _channel.invokeMethod<Map>('isNfcAvailable');
// result = {'available': true, 'enabled': true}
```

**Kotlin signature:**
```kotlin
fun isNfcAvailable(): Map<String, Boolean>
```

**Arguments:** none

**Returns:**
| Key | Type | Meaning |
|---|---|---|
| `available` | Boolean | true = device has NFC hardware |
| `enabled` | Boolean | true = NFC is currently on in system settings. Meaningless if `available` is false. |

**Errors:** none (catches all exceptions internally; returns `{available: false, enabled: false}` on any hardware query failure, logs with `kDebugMode` guard).

---

### Method: `getArmState`

Returns the current arming state and time remaining.

**Dart call:**
```dart
final result = await _channel.invokeMethod<Map>('getArmState');
// result = {'armed': true, 'remainingSec': 42}
```

**Kotlin signature:**
```kotlin
fun getArmState(): Map<String, Any>
```

**Arguments:** none

**Returns:**
| Key | Type | Meaning |
|---|---|---|
| `armed` | Boolean | Whether the service is currently armed and not expired |
| `remainingSec` | Int | Seconds remaining; 0 if disarmed or expired |

---

## Channel: `tapcard/widget`

Handles communication between the Glance home widget and the Flutter app.

### CHANNEL_VERSION = 1

---

### Method: `armFromWidget`

Called by the Kotlin widget when the user taps it. Reads the stored payload from SharedPreferences and arms the HCE service directly in Kotlin — does NOT launch the Flutter app. This method exists for the Flutter side to be informed of widget-initiated arming (for analytics/state sync only).

**Dart call:**
```dart
// Flutter registers a handler for calls from Kotlin (reverse channel)
_widgetChannel.setMethodCallHandler((call) async {
  if (call.method == 'armFromWidget') {
    // Update app state if app is in foreground
    final remainingSec = call.arguments['remainingSec'] as int;
    _notifyArmStateChanged(remainingSec);
  }
});
```

**Kotlin invokes Flutter (when app is in foreground):**
```kotlin
widgetChannel.invokeMethod("armFromWidget", mapOf("remainingSec" to 60))
```

Note: the widget arms HCE directly without Flutter. This reverse-call is a courtesy notification only. If Flutter is not running, no notification is sent — the arm still happens.

---

### Method: `openShareScreen`

Called by the widget's long-press action to deep-link into the share screen.

**Intent (Kotlin → Flutter via deep link):**
```kotlin
Intent(context, MainActivity::class.java).apply {
    action = Intent.ACTION_VIEW
    data = Uri.parse("tapcard://share")
    flags = Intent.FLAG_ACTIVITY_NEW_TASK
}
```

This is handled by go_router in Flutter, not a MethodChannel call.

---

## Error Handling Contract

All MethodChannel errors follow this shape (PlatformException):

```dart
// Dart side — always wrap in try/catch
try {
  await _channel.invokeMethod('arm', {'timeoutSec': 60});
} on PlatformException catch (e) {
  // e.code   — one of the error codes listed above (e.g. 'NFC_DISABLED')
  // e.message — human-readable description (English, for logging only)
  // e.details — optional additional context
  _handleNfcError(e.code);
}
```

```kotlin
// Kotlin side — always throw PlatformException with the defined code
result.error("NFC_DISABLED", "NFC is turned off in system settings", null)
```

---

## Dart Wrapper (`lib/platform/nfc_channel.dart`)

The raw MethodChannel must be wrapped in a typed Dart class. No feature code calls `_channel.invokeMethod` directly.

```dart
/// Typed wrapper for the tapcard/nfc platform channel.
/// All NFC arming, disarming, and state queries go through this class.
/// See .claude/PLATFORM_CHANNEL.md for the full contract.
class NfcChannel {
  static const _channel = MethodChannel('tapcard/nfc');

  /// Returns the current NFC availability state.
  Future<NfcAvailability> isNfcAvailable() async { ... }

  /// Sets the NDEF share URL payload. Must be called before [arm].
  Future<void> setPayload(String url) async { ... }

  /// Arms the HCE service for [timeoutSec] seconds (default 60).
  Future<void> arm({int timeoutSec = 60}) async { ... }

  /// Disarms the HCE service immediately.
  Future<void> disarm() async { ... }

  /// Returns the current arm state and seconds remaining.
  Future<ArmState> getArmState() async { ... }
}
```

All methods catch `PlatformException` and convert to typed `TapCardNfcException` with a `NfcErrorCode` enum. Raw `PlatformException` never leaks into feature code.
