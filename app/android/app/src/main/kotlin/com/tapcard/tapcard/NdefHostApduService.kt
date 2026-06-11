/**
 * Android HCE service that bridges NFC reader APDUs to the NdefApduProcessor.
 *
 * This class owns all Android lifecycle and SharedPreferences concerns.
 * All byte-level APDU logic lives in NdefApduProcessor so it can be unit-tested
 * without the Android framework. Reads SharedPreferences fresh on every APDU
 * because the OS can cold-start this service independent of the Flutter app.
 */
package com.tapcard.tapcard

import android.content.Intent
import android.content.SharedPreferences
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import com.tapcard.tapcard.widget.TapCardWidget
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class NdefHostApduService : HostApduService() {

    companion object {
        const val PREFS_NAME        = "tapcard_nfc"
        const val KEY_NDEF_URL      = "ndef_url"
        const val KEY_IS_ARMED      = "is_armed"
        const val KEY_EXPIRES_AT_MS = "expires_at_ms"
        const val ARM_DURATION_MS   = 60_000L

        private const val TAG = "NdefHostApduService"

        /** Local broadcast action fired when the NDEF body has been fully served to the reader. */
        const val ACTION_NFC_TAPPED = "com.tapcard.tapcard.NFC_TAPPED"
    }

    /**
     * NdefPayloadProvider implementation that reads arm state and URL from SharedPreferences.
     * Created fresh on each processCommandApdu so the service survives cold restarts.
     */
    private inner class SharedPrefsPayloadProvider(
        private val prefs: SharedPreferences
    ) : NdefPayloadProvider {

        override fun getNdefPayloadIfArmed(): String? {
            val isArmed   = prefs.getBoolean(KEY_IS_ARMED, false)
            val expiresAt = prefs.getLong(KEY_EXPIRES_AT_MS, 0L)
            val isValid   = isArmed && System.currentTimeMillis() < expiresAt

            if (!isValid) {
                if (isArmed) {
                    prefs.edit()
                        .putBoolean(KEY_IS_ARMED, false)
                        .putLong(KEY_EXPIRES_AT_MS, 0L)
                        .apply()
                    if (BuildConfig.DEBUG) Log.d(TAG, "Arm expired — auto-disarmed")
                }
                return null
            }

            return prefs.getString(KEY_NDEF_URL, null)
        }
    }

    /** Processor is per-session; reset() is called on deactivation. */
    private var processor: NdefApduProcessor? = null

    override fun processCommandApdu(commandApdu: ByteArray, extras: Bundle?): ByteArray {
        if (BuildConfig.DEBUG) Log.d(TAG, "APDU received: ${commandApdu.size} bytes")

        // getSharedPreferences returns a cached instance; provider reads values lazily on each call
        val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

        // Lazily create processor once per field session; reset on onDeactivated.
        // onNdefServed fires a local broadcast that MainActivity forwards to Flutter.
        val proc = processor ?: NdefApduProcessor(
            payloadProvider = SharedPrefsPayloadProvider(prefs),
            onNdefServed = {
                if (BuildConfig.DEBUG) Log.d(TAG, "NDEF body served — disarming and refreshing widget")
                // Disarm immediately so the widget returns to idle
                getSharedPreferences(PREFS_NAME, MODE_PRIVATE).edit()
                    .putBoolean(KEY_IS_ARMED, false)
                    .putLong(KEY_EXPIRES_AT_MS, 0L)
                    .apply()
                // Refresh the home-screen widget
                CoroutineScope(Dispatchers.Main).launch {
                    TapCardWidget().updateAll(this@NdefHostApduService)
                }
                // Notify Flutter app if in foreground
                LocalBroadcastManager.getInstance(this)
                    .sendBroadcast(Intent(ACTION_NFC_TAPPED))
            },
        ).also { processor = it }

        return try {
            proc.process(commandApdu)
        } catch (e: Exception) {
            // Catch any unexpected exception to avoid crashing the HCE service
            if (BuildConfig.DEBUG) Log.e(TAG, "Unexpected error in processCommandApdu", e)
            NdefApduProcessor.SW_UNKNOWN
        }
    }

    override fun onDeactivated(reason: Int) {
        processor?.reset()
        processor = null
        if (BuildConfig.DEBUG) Log.d(TAG, "Deactivated reason=$reason")
    }
}
