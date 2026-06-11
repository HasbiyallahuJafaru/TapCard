/**
 * Glance [ActionCallback] invoked when the user taps the armed TapCard widget.
 *
 * Disarms NFC HCE by clearing SharedPreferences and refreshes the widget back to idle.
 * Mirrors ArmNfcAction but in reverse — no Flutter app launch needed.
 */
package com.tapcard.tapcard.widget

import android.content.Context
import android.util.Log
import androidx.glance.GlanceId
import androidx.glance.action.ActionParameters
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.action.ActionCallback
import com.tapcard.tapcard.BuildConfig
import com.tapcard.tapcard.NdefHostApduService

class DisarmNfcAction : ActionCallback {

    companion object {
        private const val TAG = "DisarmNfcAction"
    }

    override suspend fun onAction(
        context: Context,
        glanceId: GlanceId,
        parameters: ActionParameters,
    ) {
        val prefs = context.getSharedPreferences(NdefHostApduService.PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(NdefHostApduService.KEY_IS_ARMED, false)
            .putLong(NdefHostApduService.KEY_EXPIRES_AT_MS, 0L)
            .commit()

        if (BuildConfig.DEBUG) Log.d(TAG, "Widget disarmed HCE")

        // Refresh all widget instances back to idle.
        GlanceAppWidgetManager(context)
            .getGlanceIds(TapCardWidget::class.java)
            .forEach { TapCardWidget().update(context, it) }
    }
}
