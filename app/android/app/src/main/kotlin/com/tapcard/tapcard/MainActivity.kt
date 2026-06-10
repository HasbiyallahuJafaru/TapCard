/**
 * Application entry point. Extends FlutterActivity and registers two MethodChannel handlers:
 *   1. NfcPlugin  — tapcard/nfc   — arm, disarm, availability queries.
 *   2. Widget channel — tapcard/widget — reverse notifications from Kotlin to Flutter.
 *
 * Also registers two BroadcastReceivers while the activity is in the foreground:
 *   - NFC_TAPPED receiver: fired by NdefHostApduService after NDEF body is served;
 *     invokes Flutter armStateProvider.triggerSuccess() via nfcChannel.invokeMethod.
 *   - WIDGET_ARMED receiver: fired by ArmNfcAction when the widget arms HCE;
 *     invokes Flutter armFromWidget via widgetChannel.invokeMethod.
 */
package com.tapcard.tapcard

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val WIDGET_CHANNEL = "tapcard/widget"
        private const val NFC_CHANNEL    = "tapcard/nfc"
    }

    private var nfcChannel: MethodChannel? = null
    private var widgetChannel: MethodChannel? = null

    /** Fired by NdefHostApduService (local broadcast) when NDEF body is fully served. */
    private val nfcTappedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (BuildConfig.DEBUG) Log.d(TAG, "NFC_TAPPED → notifying Flutter")
            nfcChannel?.invokeMethod("onTapSuccess", null)
        }
    }

    /** Fired by ArmNfcAction (global broadcast, package-restricted) when widget arms HCE. */
    private val widgetArmedReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val remainingSec = intent.getIntExtra("remainingSec", 60)
            if (BuildConfig.DEBUG) Log.d(TAG, "WIDGET_ARMED remainingSec=$remainingSec → notifying Flutter")
            widgetChannel?.invokeMethod("armFromWidget", mapOf("remainingSec" to remainingSec))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        nfcChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NFC_CHANNEL,
        ).also { it.setMethodCallHandler(NfcPlugin(applicationContext)) }

        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        )
        // Flutter registers the reverse handler via widget_channel.dart.
        // Kotlin only invokes methods on this channel (armFromWidget).
    }

    override fun onResume() {
        super.onResume()
        // Register NFC tap receiver (local — only within this process).
        LocalBroadcastManager.getInstance(this).registerReceiver(
            nfcTappedReceiver,
            IntentFilter(NdefHostApduService.ACTION_NFC_TAPPED),
        )
        // Register widget arm receiver (explicit broadcast, package-restricted).
        registerReceiver(
            widgetArmedReceiver,
            IntentFilter("com.tapcard.tapcard.WIDGET_ARMED"),
            Context.RECEIVER_NOT_EXPORTED,
        )
    }

    override fun onPause() {
        LocalBroadcastManager.getInstance(this).unregisterReceiver(nfcTappedReceiver)
        unregisterReceiver(widgetArmedReceiver)
        super.onPause()
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nfcChannel = null
        widgetChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
