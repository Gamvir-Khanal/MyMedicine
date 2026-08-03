package com.example.med_reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Fired directly by AlarmManager (registered via AlarmScheduler), not by
 * flutter_local_notifications. Its only job is to hand off to
 * AlarmService, which decides whether the screen is currently unlocked
 * and, if so, launches AlarmRingScreen immediately instead of waiting
 * for a notification tap.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        val payload = intent.getStringExtra("payload") ?: ""

        val serviceIntent = Intent(context, AlarmService::class.java).apply {
            putExtra("id", id)
            putExtra("payload", payload)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }
}
