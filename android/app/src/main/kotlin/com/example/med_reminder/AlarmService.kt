package com.example.med_reminder

import android.app.ActivityOptions
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.NotificationCompat

class AlarmService : Service() {

    companion object {
        private const val TAG = "AlarmService"
        const val ACTION_START_ALARM = "com.example.med_reminder.ACTION_START_ALARM"
        const val ACTION_STOP_ALARM = "com.example.med_reminder.ACTION_STOP_ALARM"
        private const val SERVICE_CHANNEL_ID = "medicine_reminders_alarm_channel"
        private const val SERVICE_NOTIFICATION_ID = 10001
        private const val AUTO_DISMISS_TIMEOUT_MS = 120_000L // 2 minutes

        fun stopAlarm(context: Context) {
            try {
                AlarmSoundPlayer.stop()
                val stopIntent = Intent(context, AlarmService::class.java).apply {
                    action = ACTION_STOP_ALARM
                }
                context.startService(stopIntent)
            } catch (e: Exception) {
                Log.w(TAG, "Error requesting stopAlarm: ${e.message}")
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null
    private val handler = Handler(Looper.getMainLooper())
    private val autoDismissRunnable = Runnable {
        Log.d(TAG, "Auto-dismiss timeout reached after 2 minutes")
        stopAlarmInternal()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP_ALARM) {
            Log.d(TAG, "Received ACTION_STOP_ALARM")
            stopAlarmInternal()
            return START_NOT_STICKY
        }

        val payload = intent?.getStringExtra("payload") ?: ""
        val id = intent?.getIntExtra("id", 0) ?: 0

        val parts = payload.split('|')
        val medicineName = if (parts.size > 2 && parts[2].isNotEmpty()) parts[2] else "Medicine"
        val dosageInfo = if (parts.size > 3 && parts[3].isNotEmpty()) parts[3] else "Time to take your medicine"
        val customSoundPath = if (parts.size > 4 && parts[4].isNotEmpty()) parts[4] else null

        // 1. Acquire WakeLock so device stays awake during alarm
        acquireWakeLock()

        // 2. Start native alarm audio and vibration immediately
        AlarmSoundPlayer.start(this, customSoundPath)

        // 3. Build & start foreground notification with FullScreenIntent
        val notification = buildAlarmNotification(id, medicineName, dosageInfo, payload)
        startForeground(SERVICE_NOTIFICATION_ID, notification)

        // 4. Directly launch MainActivity over lock screen / current app
        launchAlarmScreen(payload)

        // 5. Schedule safety timeout
        handler.removeCallbacks(autoDismissRunnable)
        handler.postDelayed(autoDismissRunnable, AUTO_DISMISS_TIMEOUT_MS)

        return START_STICKY
    }

    private fun acquireWakeLock() {
        try {
            if (wakeLock == null) {
                val powerManager = getSystemService(POWER_SERVICE) as PowerManager
                @Suppress("DEPRECATION")
                val flags = PowerManager.SCREEN_BRIGHT_WAKE_LOCK or
                        PowerManager.ACQUIRE_CAUSES_WAKEUP or
                        PowerManager.ON_AFTER_RELEASE
                wakeLock = powerManager.newWakeLock(flags, "med_reminder:AlarmWakeLock").apply {
                    setReferenceCounted(false)
                    acquire(AUTO_DISMISS_TIMEOUT_MS)
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to acquire wake lock: ${e.message}")
        }
    }

    private fun releaseWakeLock() {
        try {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to release wake lock: ${e.message}")
        } finally {
            wakeLock = null
        }
    }

    private fun stopAlarmInternal() {
        handler.removeCallbacks(autoDismissRunnable)
        AlarmSoundPlayer.stop()
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacks(autoDismissRunnable)
        AlarmSoundPlayer.stop()
        releaseWakeLock()
        super.onDestroy()
    }

    private fun launchAlarmScreen(payload: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_ALARM_SCREEN
            putExtra("payload", payload)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                val options = ActivityOptions.makeBasic().apply {
                    setPendingIntentBackgroundActivityStartMode(
                        ActivityOptions.MODE_BACKGROUND_ACTIVITY_START_ALLOWED
                    )
                }
                startActivity(launchIntent, options.toBundle())
            } else {
                startActivity(launchIntent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Direct launch failed: ${e.message}", e)
        }
    }

    private fun buildAlarmNotification(
        id: Int,
        medicineName: String,
        dosageInfo: String,
        payload: String
    ): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Medicine Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority full-screen alarms for medicine reminders"
                setSound(null, null) // Handled natively by AlarmSoundPlayer
                enableVibration(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setBypassDnd(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val fullScreenIntent = Intent(this, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_ALARM_SCREEN
            putExtra("payload", payload)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            if (id != 0) id else 999,
            fullScreenIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setContentTitle("Medicine Reminder: $medicineName")
            .setContentText(dosageInfo)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setContentIntent(fullScreenPendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
    }
}