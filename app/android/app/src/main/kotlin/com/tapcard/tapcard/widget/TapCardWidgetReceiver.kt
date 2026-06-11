/**
 * Glance AppWidget receiver for TapCardWidget.
 *
 * Handles the standard widget lifecycle (add/update/remove) and the custom
 * WIDGET_REFRESH broadcast that fires when:
 *   - the arm window expires (AlarmManager one-shot from ArmNfcAction), or
 *   - an NFC tap succeeds (NdefHostApduService disarms and sends this broadcast).
 *
 * GlanceAppWidgetReceiver.onReceive only handles standard appwidget intents
 * automatically. For WIDGET_REFRESH we must call .update() explicitly.
 */
package com.tapcard.tapcard.widget

import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.launch

class TapCardWidgetReceiver : GlanceAppWidgetReceiver() {

    override val glanceAppWidget: GlanceAppWidget = TapCardWidget()

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == "com.tapcard.tapcard.WIDGET_REFRESH") {
            MainScope().launch {
                val manager = GlanceAppWidgetManager(context)
                manager.getGlanceIds(TapCardWidget::class.java).forEach { id ->
                    TapCardWidget().update(context, id)
                }
            }
        }
    }
}
