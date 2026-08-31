package com.romashka.linnet

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class RingtoneService : Service() {

    companion object {
        const val ACTION_START = "START_RINGTONE"
        const val ACTION_STOP = "STOP_RINGTONE"

        private const val FOREGROUND_NOTIFICATION_ID = 1002
        private const val FOREGROUND_CHANNEL_ID = "call_ringtone_service"
    }

    private var player: MediaPlayer? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        when (intent?.action) {
            ACTION_START -> startRingtone()
            ACTION_STOP -> {
                // Если сервис поднят через startForegroundService() (Android 8+)
                // именно для остановки — система всё равно ждёт вызов
                // startForeground() в течение нескольких секунд, иначе кинет
                // ForegroundServiceDidNotStartInTimeException. Поэтому
                // промоутимся и сразу останавливаемся.
                if (player == null) {
                    ensureForeground()
                }
                stopRingtone()
            }
        }

        return START_NOT_STICKY
    }

    private fun ensureForeground() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager =
                getSystemService(NOTIFICATION_SERVICE) as NotificationManager

            if (manager.getNotificationChannel(FOREGROUND_CHANNEL_ID) == null) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        FOREGROUND_CHANNEL_ID,
                        "Воспроизведение рингтона",
                        NotificationManager.IMPORTANCE_LOW
                    )
                )
            }
        }

        val notification = NotificationCompat.Builder(this, FOREGROUND_CHANNEL_ID)
            .setContentTitle("Входящий звонок")
            .setSmallIcon(applicationInfo.icon)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        // Обязательно: сервис задекларирован в манифесте с
        // foregroundServiceType="mediaPlayback", поэтому система ожидает
        // вызов startForeground() почти сразу после старта (Android 8+),
        // а на Android 12+ отсутствие вызова в течение нескольких секунд
        // роняет процесс с ForegroundServiceDidNotStartInTimeException.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                FOREGROUND_NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(FOREGROUND_NOTIFICATION_ID, notification)
        }
    }

    private fun startRingtone() {
        // Если рингтон уже играет — ничего не делаем.
        if (player != null) {
            return
        }

        ensureForeground()

        val resourceId = resources.getIdentifier(
            "incoming_ringtone",
            "raw",
            packageName
        )

        // Файл incoming_ringtone не найден.
        if (resourceId == 0) {
            stopSelf()
            return
        }

        try {
            val mediaPlayer = MediaPlayer()

            val uri = Uri.parse(
                "android.resource://$packageName/$resourceId"
            )

            mediaPlayer.setDataSource(this, uri)

            mediaPlayer.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(
                        AudioAttributes.USAGE_NOTIFICATION_RINGTONE
                    )
                    .setContentType(
                        AudioAttributes.CONTENT_TYPE_MUSIC
                    )
                    .build()
            )

            // Зацикливаем рингтон.
            mediaPlayer.isLooping = true

            mediaPlayer.prepare()

            mediaPlayer.start()

            player = mediaPlayer

        } catch (e: Exception) {
            player?.release()
            player = null
            stopSelf()
        }
    }

    private fun stopRingtone() {
        val currentPlayer = player

        player = null

        if (currentPlayer != null) {
            try {
                if (currentPlayer.isPlaying) {
                    currentPlayer.stop()
                }
            } catch (_: Exception) {
            }

            try {
                currentPlayer.release()
            } catch (_: Exception) {
            }
        }

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopRingtone()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }
}