/**
 * TapCard home-screen Glance widget.
 *
 * States:
 *   Idle   — NFC icon + "TAP TO SHARE" + "TapCard" label.
 *   Armed  — countdown seconds + "READY" label. Ring icon (text approximation).
 *
 * Tapping the widget when idle calls [ArmNfcAction] which writes SharedPreferences
 * and arms HCE directly without launching the Flutter app. If the app is in the
 * foreground, it receives an [armFromWidget] courtesy notification via the widget channel.
 *
 * Visual spec: .claude/UI_DIRECTION.md §Glance Widget Direction.
 */
package com.tapcard.tapcard.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.action.actionRunCallback
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.text.FontFamily
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.tapcard.tapcard.NdefHostApduService

// ─── Design tokens (approximated from AppColours for Glance) ────────────────

private val BgSecondary    = Color(0xFF161616)
private val TextPrimary    = Color(0xFFF2F0EC)
private val TextSecondary  = Color(0xFF9E9B96)
private val TextTertiary   = Color(0xFF5C5A57)
private val NfcArmed       = Color(0xFFF2F0EC)

class TapCardWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val armState = readArmState(context)
        provideContent {
            GlanceTheme {
                WidgetContent(armState)
            }
        }
    }

    @Composable
    private fun WidgetContent(armState: ArmState) {
        Box(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(BgSecondary)
                .padding(12.dp),
            contentAlignment = Alignment.Center,
        ) {
            when (armState) {
                is ArmState.Idle  -> IdleContent()
                is ArmState.Armed -> ArmedContent(armState.remainingSec)
            }
        }
    }

    @Composable
    private fun IdleContent() {
        Column(
            modifier = GlanceModifier
                .fillMaxWidth()
                .clickable(actionRunCallback<ArmNfcAction>()),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // App name label — top left per spec, but centred works in 2×1 size.
            Text(
                text = "TAPCARD",
                style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(TextTertiary),
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = FontFamily.SansSerif,
                ),
            )
            Spacer(GlanceModifier.height(8.dp))
            // NFC icon approximation — Unicode NFC symbol.
            Text(
                text = "((·))",
                style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(TextSecondary),
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Normal,
                    fontFamily = FontFamily.Monospace,
                ),
            )
            Spacer(GlanceModifier.height(6.dp))
            Text(
                text = "TAP TO SHARE",
                style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(TextSecondary),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = FontFamily.SansSerif,
                ),
            )
        }
    }

    @Composable
    private fun ArmedContent(remainingSec: Int) {
        Column(
            modifier = GlanceModifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "$remainingSec",
                style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(NfcArmed),
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Normal,
                    fontFamily = FontFamily.Monospace,
                ),
            )
            Spacer(GlanceModifier.height(4.dp))
            Text(
                text = "READY",
                style = TextStyle(
                    color = androidx.glance.unit.ColorProvider(TextPrimary),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    fontFamily = FontFamily.SansSerif,
                ),
            )
        }
    }
}

// ─── Arm state helpers ───────────────────────────────────────────────────────

sealed class ArmState {
    data object Idle : ArmState()
    data class Armed(val remainingSec: Int) : ArmState()
}

fun readArmState(context: Context): ArmState {
    val prefs     = context.getSharedPreferences(NdefHostApduService.PREFS_NAME, Context.MODE_PRIVATE)
    val isArmed   = prefs.getBoolean(NdefHostApduService.KEY_IS_ARMED, false)
    val expiresAt = prefs.getLong(NdefHostApduService.KEY_EXPIRES_AT_MS, 0L)
    val now       = System.currentTimeMillis()

    return if (isArmed && now < expiresAt) {
        ArmState.Armed(remainingSec = ((expiresAt - now) / 1_000L).toInt().coerceAtLeast(1))
    } else {
        ArmState.Idle
    }
}
