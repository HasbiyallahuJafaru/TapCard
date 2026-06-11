/**
 * Flutter MethodChannel handler for the tapcard/nfc channel.
 *
 * Implements setPayload, arm, disarm, isNfcAvailable, and getArmState.
 * All SharedPreferences writes use the same PREFS_NAME and key constants as NdefHostApduService
 * so the HCE service picks them up on cold start without any IPC.
 * This file handles channel plumbing only — APDU logic lives in NdefHostApduService.kt.
 */
package com.tapcard.tapcard

import android.content.Context
import android.nfc.NfcAdapter
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.Result

class NfcPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME    = "tapcard/nfc"
        const val CHANNEL_VERSION = 1

        // vCard payload length guard (UTF-8 bytes) — typical vCard is well under 2KB
        private const val MAX_VCARD_BYTES = 4_096

        // arm() timeout clamp bounds (seconds)
        private const val ARM_TIMEOUT_MIN_SEC = 10
        private const val ARM_TIMEOUT_MAX_SEC = 300

        // PlatformException error codes (frozen — see PLATFORM_CHANNEL.md)
        private const val ERR_INVALID_URL    = "INVALID_URL"
        private const val ERR_PAYLOAD_TOO_LONG = "PAYLOAD_TOO_LONG"
        private const val ERR_NO_PAYLOAD     = "NO_PAYLOAD"
        private const val ERR_NFC_UNAVAILABLE = "NFC_UNAVAILABLE"
        private const val ERR_NFC_DISABLED   = "NFC_DISABLED"

        private const val TAG = "NfcPlugin"
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (BuildConfig.DEBUG) Log.d(TAG, "method=${call.method}")
        when (call.method) {
            "setPayload"     -> handleSetPayload(call, result)
            "arm"            -> handleArm(call, result)
            "disarm"         -> handleDisarm(result)
            "isNfcAvailable" -> handleIsNfcAvailable(result)
            "getArmState"    -> handleGetArmState(result)
            else             -> result.notImplemented()
        }
    }

    /**
     * Stores the vCard payload in SharedPreferences.
     * Does NOT arm sharing — call [arm] separately.
     *
     * @throws INVALID_URL if vcard is blank
     * @throws PAYLOAD_TOO_LONG if vcard exceeds MAX_VCARD_BYTES bytes (UTF-8)
     */
    private fun handleSetPayload(call: MethodCall, result: Result) {
        val vCard = call.argument<String>("vcard")
        if (vCard.isNullOrBlank()) {
            result.error(ERR_INVALID_URL, "vcard must not be blank", null)
            return
        }
        val byteLen = vCard.toByteArray(Charsets.UTF_8).size
        if (byteLen > MAX_VCARD_BYTES) {
            result.error(ERR_PAYLOAD_TOO_LONG, "vCard exceeds $MAX_VCARD_BYTES bytes", null)
            return
        }

        val prefs = context.getSharedPreferences(NdefHostApduService.PREFS_NAME, Context.MODE_PRIVATE)
        val written = prefs.edit().putString(NdefHostApduService.KEY_NDEF_URL, vCard).commit()
        result.success(written)
    }

    /**
     * Arms the HCE service. Writes is_armed and expires_at_ms to SharedPreferences.
     * [timeoutSec] is clamped to [ARM_TIMEOUT_MIN_SEC, ARM_TIMEOUT_MAX_SEC].
     *
     * @throws NO_PAYLOAD if setPayload has not been called
     * @throws NFC_UNAVAILABLE if device has no NFC hardware
     * @throws NFC_DISABLED if NFC is off in system settings
     */
    private fun handleArm(call: MethodCall, result: Result) {
        val adapter = NfcAdapter.getDefaultAdapter(context)
        if (adapter == null) {
            result.error(ERR_NFC_UNAVAILABLE, "Device has no NFC hardware", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error(ERR_NFC_DISABLED, "NFC is turned off in system settings", null)
            return
        }

        val prefs = context.getSharedPreferences(NdefHostApduService.PREFS_NAME, Context.MODE_PRIVATE)
        if (!prefs.contains(NdefHostApduService.KEY_NDEF_URL)) {
            result.error(ERR_NO_PAYLOAD, "Call setPayload before arm", null)
            return
        }

        val rawTimeoutSec  = call.argument<Int>("timeoutSec") ?: 60
        val timeoutSec     = rawTimeoutSec.coerceIn(ARM_TIMEOUT_MIN_SEC, ARM_TIMEOUT_MAX_SEC)
        val timeoutMs      = timeoutSec.toLong() * 1_000L
        val expiresAt      = System.currentTimeMillis() + timeoutMs

        val written = prefs.edit()
            .putBoolean(NdefHostApduService.KEY_IS_ARMED, true)
            .putLong(NdefHostApduService.KEY_EXPIRES_AT_MS, expiresAt)
            .commit()

        if (BuildConfig.DEBUG) Log.d(TAG, "Armed for ${timeoutSec}s, expiresAt=$expiresAt")
        result.success(written)
    }

    /**
     * Disarms the HCE service immediately. Idempotent — safe to call when already disarmed.
     */
    private fun handleDisarm(result: Result) {
        val prefs = context.getSharedPreferences(NdefHostApduService.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(NdefHostApduService.KEY_IS_ARMED, false)
            .putLong(NdefHostApduService.KEY_EXPIRES_AT_MS, 0L)
            .apply()
        if (BuildConfig.DEBUG) Log.d(TAG, "Disarmed")
        result.success(null)
    }

    /**
     * Returns a map with NFC hardware availability and enabled state.
     * Never throws — catches all exceptions and returns {available: false, enabled: false}.
     *
     * @return Map<String, Boolean> with keys "available" and "enabled"
     */
    private fun handleIsNfcAvailable(result: Result) {
        try {
            val adapter = NfcAdapter.getDefaultAdapter(context)
            val available = adapter != null
            val enabled   = adapter?.isEnabled ?: false
            result.success(mapOf("available" to available, "enabled" to enabled))
        } catch (e: Exception) {
            if (BuildConfig.DEBUG) Log.e(TAG, "isNfcAvailable error", e)
            result.success(mapOf("available" to false, "enabled" to false))
        }
    }

    /**
     * Returns the current arm state and seconds remaining.
     *
     * @return Map<String, Any> with keys "armed" (Boolean) and "remainingSec" (Int)
     */
    private fun handleGetArmState(result: Result) {
        val prefs     = context.getSharedPreferences(NdefHostApduService.PREFS_NAME, Context.MODE_PRIVATE)
        val isArmed   = prefs.getBoolean(NdefHostApduService.KEY_IS_ARMED, false)
        val expiresAt = prefs.getLong(NdefHostApduService.KEY_EXPIRES_AT_MS, 0L)
        val now       = System.currentTimeMillis()

        val isValid       = isArmed && now < expiresAt
        val remainingSec  = if (isValid) ((expiresAt - now) / 1_000L).toInt() else 0

        result.success(mapOf("armed" to isValid, "remainingSec" to remainingSec))
    }
}
