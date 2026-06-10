/**
 * Glance AppWidget receiver for TapCardWidget.
 *
 * Handles the standard widget lifecycle (add/update/remove) and the custom
 * WIDGET_REFRESH alarm that fires when the arm window expires, triggering
 * a widget UI refresh back to idle state.
 */
package com.tapcard.tapcard.widget

import android.content.Context
import android.content.Intent
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver

class TapCardWidgetReceiver : GlanceAppWidgetReceiver() {

    override val glanceAppWidget: GlanceAppWidget = TapCardWidget()

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Handle the expiry alarm — just calling super triggers a widget update
        // which re-reads SharedPreferences and renders the idle state.
    }
}
