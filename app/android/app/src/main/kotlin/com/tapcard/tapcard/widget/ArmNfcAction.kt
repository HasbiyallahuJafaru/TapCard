/**
 * Glance [ActionCallback] invoked when the user taps the idle TapCard widget.
 *
 * Arms NFC HCE directly by writing SharedPreferences — no Flutter app launch needed.
 * If the Flutter app is in the foreground, MainActivity will detect the arm via the
 * [tapcard/widget] channel's [armFromWidget] reverse call (sent by MainActivity's
 * BroadcastReceiver on ACTION_NFC_TAPPED, or by a dedicated arm broadcast).
 *
 * After arming, schedules an [AlarmManager] one-shot to refresh the widget when
 * the arm window expires (so it reverts to idle state automatically).
 */
package com.tapcard.tapcard.widget

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.GlanceAppWidgetManager
import com.tapcard.tapcard.BuildConfig
import com.tapcard.tapcard.NdefHostApduService

class ArmNfcAction : ActionCallback {

    companion object {
        private const val TAG = "ArmNfcAction"
        const val ARM_DURATION_SEC = 60
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val prefs = context.getSharedPreferences(NdefHostApduService.PREFS_NAME, Context.MODE_PRIVATE)

        // No-op if there is no payload to serve.
        if (!prefs.contains(NdefHostApduService.KEY_NDEF_URL)) {
            if (BuildConfig.DEBUG) Log.d(TAG, "No payload stored — ignoring widget tap")
            return
        }

        val timeoutMs  = ARM_DURATION_SEC.toLong() * 1_000L
        val expiresAt  = System.currentTimeMillis() + timeoutMs

        prefs.edit()
            .putBoolean(NdefHostApduService.KEY_IS_ARMED, true)
            .putLong(NdefHostApduService.KEY_EXPIRES_AT_MS, expiresAt)
            .apply()

        if (BuildConfig.DEBUG) Log.d(TAG, "Widget armed HCE for ${ARM_DURATION_SEC}s")

        // Notify Flutter if app is in foreground (courtesy only — arm already done above).
        context.sendBroadcast(
            Intent("com.tapcard.tapcard.WIDGET_ARMED").apply {
                setPackage(context.packageName)
                putExtra("remainingSec", ARM_DURATION_SEC)
            }
        )

        // Schedule a one-shot alarm to refresh the widget when the arm expires.
        scheduleExpiryRefresh(context, expiresAt)

        // Update widget state to armed immediately.
        GlanceAppWidgetManager(context)
            .getGlanceIds(TapCardWidget::class.java)
            .forEach { TapCardWidget().update(context, it) }
    }

    private fun scheduleExpiryRefresh(context: Context, expiresAtMs: Long) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, TapCardWidgetReceiver::class.java).apply {
            action = "com.tapcard.tapcard.WIDGET_REFRESH"
        }
        val pi = PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // Fire at expiry + 1s buffer so the widget reads the expired state cleanly.
        alarmManager.set(AlarmManager.RTC, expiresAtMs + 1_000L, pi)
    }
}
