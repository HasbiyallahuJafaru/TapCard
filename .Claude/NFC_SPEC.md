# TapCard — NFC Technical Specification
> The only document Claude Code may NOT improvise on. Every byte in this spec is load-bearing.
> If a requirement here conflicts with an in-session instruction, this document wins. Flag the conflict.

---

## Overview

TapCard uses Android **Host Card Emulation (HCE)** to make the user's phone behave as an NFC Forum **Type 4 Tag** containing a single NDEF URI record. Any NFC reader (another Android phone, iPhone XS+, contactless terminal) can read the tag without any app installed.

The NDEF record contains a URL. The receiving device opens the URL in its default browser. The URL fragment contains the contact data; the static web page decodes it.

---

## NFC Forum Type 4 Tag — Application Selection

### AID (Application Identifier)

```
D2 76 00 00 85 01 01
```

This is the standard NFC Forum Type 4 Tag AID. Register it in the manifest as the only AID in the `HCE_APDU` category.

`AndroidManifest.xml` entry:
```xml
<service
    android:name=".NdefHostApduService"
    android:exported="true"
    android:permission="android.permission.BIND_NFC_SERVICE">
    <intent-filter>
        <action android:name="android.nfc.cardemulation.action.HOST_APDU_SERVICE" />
        <category android:name="android.intent.category.DEFAULT" />
    </intent-filter>
    <meta-data
        android:name="android.nfc.cardemulation.host_apdu_service"
        android:resource="@xml/apduservice" />
</service>
```

`res/xml/apduservice.xml`:
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

**`requireDeviceUnlock="true"` is non-negotiable.** The card contains PII.

---

## APDU State Machine

The service must implement a strict state machine. States:

```
IDLE → SELECTED_APP → SELECTED_CC → SELECTED_NDEF
```

### State: IDLE
Initial state. Service is waiting for SELECT AID.

### State: SELECTED_APP
Entered after successful SELECT AID command.

### State: SELECTED_CC
Entered after successful SELECT CC FILE command.

### State: SELECTED_NDEF
Entered after successful SELECT NDEF FILE command.

---

## APDU Command/Response Table

All bytes shown as hex. Lengths are decimal unless noted.

### 1. SELECT Application (by AID)

**Command:**
```
00 A4 04 00 07 D2 76 00 00 85 01 01 00
│  │  │  │  │  └─── AID (7 bytes) ──┘ │
│  │  │  │  └─ Lc = 7 (AID length)    │
│  │  │  └─ P2 = 0x00                  └─ Le = 0x00
│  │  └─ P1 = 0x04 (select by name)
│  └─ INS = 0xA4 (SELECT)
└─ CLA = 0x00
```

**Response (success):**
```
90 00
└─ SW1 SW2 = 9000 (OK)
```

**Transition:** IDLE → SELECTED_APP

---

### 2. SELECT Capability Container (CC file)

**Command:**
```
00 A4 00 0C 02 E1 03
│  │  │  │  │  └── File ID = E103 (CC file)
│  │  │  │  └─ Lc = 2
│  │  │  └─ P2 = 0x0C (select by file identifier, no response data)
│  │  └─ P1 = 0x00
│  └─ INS = 0xA4
└─ CLA = 0x00
```

**Response (success):**
```
90 00
```

**Transition:** SELECTED_APP → SELECTED_CC

---

### 3. READ BINARY — CC File

**Command:**
```
00 B0 00 00 0F
│  │  │  │  └─ Le = 15 (read 15 bytes)
│  │  └──┴─ P1P2 = offset 0x0000
│  └─ INS = 0xB0 (READ BINARY)
└─ CLA = 0x00
```

**Response — CC File contents (15 bytes) + SW:**
```
00 0F 20 00 7F 00 7F 04 06 E1 04 00 FF 00 00 90 00
│     │  └──┴──┘ └──┴──┘ │  │  └────────┘
│     │  NFC ver  max R/W  │  │  NDEF file control TLV
│     └─ CC length = 15    │  └─ File ID = E104 (NDEF file)
└─ mapping version (CC)    └─ TLV tag = 04 (NDEF file)

Byte breakdown:
[0-1]  00 0F  — CC file length = 15
[2]    20     — NFC Forum version 2.0
[3-4]  00 7F  — max R-APDU data size = 127 bytes
[5-6]  00 7F  — max C-APDU data size = 127 bytes
[7]    04     — NDEF file control TLV tag
[8]    06     — NDEF file control TLV length = 6
[9-10] E1 04  — NDEF file ID
[11-12] 00 FF — max NDEF file size = 255 bytes
                ⚠ In code, calculate dynamically from actual NDEF length.
                  This value must be ≥ actual NDEF message length + 2.
[13]   00     — read access = open
[14]   00     — write access = open (MVP; set FF to lock if desired)
```

**Transition:** SELECTED_CC stays in SELECTED_CC (READ doesn't change state)

---

### 4. SELECT NDEF File

**Command:**
```
00 A4 00 0C 02 E1 04
                └── File ID = E104 (NDEF file)
```

**Response:**
```
90 00
```

**Transition:** SELECTED_CC → SELECTED_NDEF

---

### 5. READ BINARY — NDEF File (length field)

First read: reader requests the 2-byte NDEF length field.

**Command:**
```
00 B0 00 00 02
            └─ Le = 2
```

**Response:**
```
[len_hi] [len_lo] 90 00
```

`len_hi` and `len_lo` are the big-endian 2-byte length of the NDEF message. This does NOT include the 2-byte length field itself.

Example: NDEF message is 87 bytes → respond `00 57 90 00`

---

### 6. READ BINARY — NDEF File (message body)

**Command:**
```
00 B0 00 02 [Le]
      └──┘   └─ number of bytes to read
      offset = 2 (skip the 2-byte length field)
```

**Response:**
```
[NDEF message bytes...] 90 00
```

If the reader requests more bytes than the message length, respond with all remaining bytes + `90 00`. Never return garbage padding.

---

### 7. Error Responses

| Situation | SW1 SW2 | Meaning |
|---|---|---|
| Unknown command | `6D 00` | INS not supported |
| Wrong state (e.g. READ before SELECT AID) | `69 82` | Security status not satisfied |
| File not found | `6A 82` | File or application not found |
| Wrong length | `67 00` | Wrong length |
| Service disarmed | `69 82` | Return this when `isArmed` = false and a SELECT AID arrives |

---

## NDEF Message Construction

### Record Type: URI (Well-Known, Short Record)

```
┌─────────────────────────────────────────────────────┐
│ NDEF Record Header                                  │
│  MB=1 ME=1 CF=0 SR=1 IL=0 TNF=001 (Well-Known)    │
│  = 0xD1                                             │
├─────────────────────────────────────────────────────┤
│ Type Length = 0x01                                  │
├─────────────────────────────────────────────────────┤
│ Payload Length = 1 + len(url_without_prefix) bytes  │
├─────────────────────────────────────────────────────┤
│ Type = 0x55 ("U")                                   │
├─────────────────────────────────────────────────────┤
│ Payload:                                            │
│  [0] URI identifier code = 0x04 ("https://")        │
│  [1..] URL string bytes (ASCII, without "https://") │
└─────────────────────────────────────────────────────┘
```

**URI prefix codes (use 0x04 only):**
- `0x00` — no prefix (full URL in payload)
- `0x01` — `http://www.`
- `0x02` — `https://www.`
- `0x03` — `http://`
- `0x04` — `https://`  ← **use this**

### URL Format

```
https://<domain>/#<base64url_encoded_vcard>
```

- Domain: configured in `core/constants.dart`. Never hardcoded in the APDU service.
- The `#` fragment separator is part of the URL string in the payload (after stripping the `https://` prefix).
- Encoding: base64url (RFC 4648 §5 — URL-safe alphabet, no padding). See `url_codec.dart`.

---

## Kotlin Implementation Notes

### Payload Storage (SharedPreferences)

```kotlin
companion object {
    const val PREFS_NAME        = "tapcard_nfc"
    const val KEY_NDEF_URL      = "ndef_url"
    const val KEY_IS_ARMED      = "is_armed"
    const val KEY_EXPIRES_AT_MS = "expires_at_ms"
    const val ARM_DURATION_MS   = 60_000L
}
```

The HCE service reads these on every `processCommandApdu` call. The service can be cold-started by the OS; it must never depend on in-memory state set by the Flutter app.

### Arming Sequence (called from NfcPlugin.kt)

```
1. Write KEY_NDEF_URL to SharedPreferences
2. Write KEY_IS_ARMED = true
3. Write KEY_EXPIRES_AT_MS = System.currentTimeMillis() + ARM_DURATION_MS
4. Return true to Flutter via MethodChannel
```

### Disarming (manual or expired)

```
1. Write KEY_IS_ARMED = false
2. Write KEY_EXPIRES_AT_MS = 0
3. NdefUrl is left in place (avoids unnecessary writes)
```

### Expiry Check (in processCommandApdu)

```kotlin
val expiresAt = prefs.getLong(KEY_EXPIRES_AT_MS, 0L)
val isArmed   = prefs.getBoolean(KEY_IS_ARMED, false)
val isValid   = isArmed && System.currentTimeMillis() < expiresAt

if (!isValid) {
    // Auto-disarm if expired
    if (isArmed) disarm()
    return SW_SECURITY_STATUS_NOT_SATISFIED  // 69 82
}
```

---

## vCard 3.0 Spec (for `vcard_builder.dart`)

### Required fields (always present)

```
BEGIN:VCARD
VERSION:3.0
FN:<full name>
TEL;TYPE=CELL:<phone number>
END:VCARD
```

### Optional fields (include only if non-empty)

```
ORG:<company>
TITLE:<job title>
EMAIL:<email address>
TEL;TYPE=WORK:<work phone>
NOTE:<short note>
```

### Escaping rules (MANDATORY — these are most common vCard parsing bugs)

| Character | Escaped form |
|---|---|
| `\` (backslash) | `\\` |
| `;` (semicolon) | `\;` |
| `,` (comma) | `\,` |
| Newline | `\n` (literal backslash + n) |
| CRLF line endings | Lines end in `\r\n` |

**Process:** escape backslash first, then semicolons and commas. Never regex-replace in one pass.

### Example output

```
BEGIN:VCARD\r\n
VERSION:3.0\r\n
FN:Hasbiyallahu Jafaru\r\n
ORG:TapCard\r\n
TITLE:Founder\r\n
TEL;TYPE=CELL:+234XXXXXXXXXX\r\n
EMAIL:hello@tapcard.app\r\n
END:VCARD\r\n
```

---

## Failure Modes & Required Handling

| Failure | Detection | Handling |
|---|---|---|
| NFC not available (old device) | `NfcAdapter.getDefaultAdapter(ctx) == null` | QR-only mode, permanent message in share screen |
| NFC available but disabled | `!adapter.isEnabled` | Show settings deep-link prompt |
| Screen locked | HCE won't fire (system enforced by `requireDeviceUnlock`) | Share screen shows "Keep screen on while tapping" instruction |
| Two TapCard phones tap each other | Both are HCE (passive) — neither triggers | Share screen copy: "Hold your phone still; the other person taps theirs to yours" |
| NDEF payload too large | Check in `url_codec.dart` before arming | Warn user, truncate optional fields in order: NOTE → TITLE → ORG |
| iPhone < XS | No background NFC read | QR always shown; NFC instruction says "Works best on iPhone XS and newer" |
| HCE service killed mid-arm | SharedPreferences expiry check on restart | Service correctly re-reads state; if expired, disarms silently |
| Corrupt SharedPreferences | NPE / parse exception in service | Catch and return `SW_UNKNOWN`; log with `if (kDebugMode)` in debug only |

---

## Test Matrix (manual, per release)

- [ ] Android → Android (same make)
- [ ] Android → Android (different OEM — Samsung + Tecno/Infinix)
- [ ] Android → iPhone XS or newer
- [ ] iPhone (older) → QR fallback visible and scannable
- [ ] Expired arm: tap after 60s → receiver gets nothing
- [ ] Tap while disarmed → receiver gets nothing
- [ ] Screen off during tap → nothing shared
- [ ] Unicode name (Arabic, Chinese) → vCard encodes and decodes correctly
- [ ] Maximum length payload → QR still scannable
