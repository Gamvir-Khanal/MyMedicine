package com.example.med_reminder

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AlarmBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmBootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received boot completed action: ${intent.action}")
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            action == "android.intent.action.QUICKBOOT_POWERON" ||
            action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            AlarmScheduler.restoreAlarmsOnBoot(context)
        }
    }
}
