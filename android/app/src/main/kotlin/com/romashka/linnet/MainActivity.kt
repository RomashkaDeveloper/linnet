package com.romashka.linnet

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "linnet/call_audio"
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "screenOff" -> {
                    turnScreenOff()
                    result.success(null)
                }

                "screenOn" -> {
                    turnScreenOn()
                    result.success(null)
                }

                "startRingtone" -> {
                    startRingtoneService(RingtoneService.ACTION_START)
                    result.success(null)
                }

                "stopRingtone" -> {
                    startRingtoneService(RingtoneService.ACTION_STOP)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun startRingtoneService(action: String) {
        val intent = Intent(this, RingtoneService::class.java).apply {
            this.action = action
        }

        // RingtoneService задекларирован с foregroundServiceType="mediaPlayback",
        // поэтому на Android 8+ его нужно поднимать через
        // startForegroundService(), а не startService() — иначе сервис не
        // успевает промоутиться в foreground и система его убивает.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun turnScreenOff() {
        val powerManager =
            getSystemService(Context.POWER_SERVICE) as PowerManager

        if (wakeLock?.isHeld == true) return

        wakeLock = powerManager.newWakeLock(
            PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
            "Linnet:Proximity"
        )

        wakeLock?.acquire()
    }

    private fun turnScreenOn() {
        wakeLock?.let {
            if (it.isHeld) it.release()
        }

        wakeLock = null
    }

    override fun onDestroy() {
        turnScreenOn()

        startRingtoneService(RingtoneService.ACTION_STOP)

        super.onDestroy()
    }
}