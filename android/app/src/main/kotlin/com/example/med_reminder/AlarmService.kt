package com.example.med_reminder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationCompat

/**
 * Fired by AlarmReceiver whenever a medicine reminder's scheduled time
 * arrives, in PARALLEL with flutter_local_notifications' own
 * notification/full-screen-intent path.
 *
 * Its only job is covering the case that path cannot: the screen
 * already being on and unlocked, INCLUDING while another app is in the
 * foreground. Since Android 10, a plain foreground service is no longer
 * allowed to launch an activity over another app - that exemption was
 * removed. The "Display over other apps" (SYSTEM_ALERT_WINDOW)
 * permission is the one remaining way to do this reliably, so this
 * service checks for it before attempting the direct launch.
 *
 * If the permission isn't granted, this does nothing - the user still
 * gets the heads-up notification banner as a fallback, same as before.
 *
 * When the screen is off/locked, this deliberately does nothing extra -
 * flutter_local_notifications' existing full-screen intent already
 * handles that case correctly, and launching twice would push
 * AlarmRingScreen onto the stack twice.
 */
class AlarmService : Service() {

    companion object {
        private const val SERVICE_CHANNEL_ID = "alarm_service_channel"
        private const val SERVICE_NOTIFICATION_ID = 42
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Required within a few seconds of startForegroundService() being
        // called, or the OS kills the process - do this before anything else.
        startForeground(SERVICE_NOTIFICATION_ID, buildServiceNotification())

        val payload = intent?.getStringExtra("payload") ?: ""
        val powerManager = getSystemService(POWER_SERVICE) as PowerManager

        if (powerManager.isInteractive && canLaunchOverOtherApps()) {
            launchAlarmScreen(payload)
        }
        // else: either screen is off/locked (flutter_local_notifications'
        // full-screen intent already covers that), or overlay permission
        // isn't granted (heads-up notification banner is the fallback).

        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf(startId)
        return START_NOT_STICKY
    }

    private fun canLaunchOverOtherApps(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun launchAlarmScreen(payload: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_ALARM_SCREEN
            putExtra("payload", payload)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        startActivity(launchIntent)
    }

    private fun buildServiceNotification(): Notification {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SERVICE_CHANNEL_ID,
                "Alarm delivery",
                NotificationManager.IMPORTANCE_MIN
            ).apply {
                description = "Used briefly to deliver medicine alarms reliably"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setContentTitle("Medicine reminder")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(false)
            .build()
    }
}