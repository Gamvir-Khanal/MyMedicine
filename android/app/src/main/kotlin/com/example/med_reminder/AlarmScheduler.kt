package com.example.med_reminder

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.util.Calendar

object AlarmScheduler {
    private const val TAG = "AlarmScheduler"
    private const val PREFS_NAME = "med_reminder_alarms_prefs"

    fun schedule(context: Context, id: Int, triggerAtMillis: Long, payload: String) {
        saveAlarmToPrefs(context, id, triggerAtMillis, payload)

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, AlarmReceiver::class.java).apply {
            action = AlarmService.ACTION_START_ALARM
            putExtra("id", id)
            putExtra("payload", payload)
        }
        val pendingIntent = PendingIntent.getBroadcast(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val showIntent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_OPEN_ALARM_SCREEN
            putExtra("payload", payload)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val showPendingIntent = PendingIntent.getActivity(
            context,
            id,
            showIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
                    alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                    Log.d(TAG, "Scheduled AlarmClock for id=$id at $triggerAtMillis")
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                    )
                    Log.d(TAG, "Scheduled setAndAllowWhileIdle (fallback) for id=$id at $triggerAtMillis")
                }
            } else {
                val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showPendingIntent)
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                Log.d(TAG, "Scheduled AlarmClock for id=$id at $triggerAtMillis")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm via setAlarmClock, trying setExactAndAllowWhileIdle fallback: ${e.message}")
            try {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP, triggerAtMillis, pendingIntent
                )
            } catch (e2: Exception) {
                Log.e(TAG, "Failed fallback scheduling: ${e2.message}")
            }
        }
    }

    fun cancel(context: Context, id: Int) {
        removeAlarmFromPrefs(context, id)
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = AlarmService.ACTION_START_ALARM
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            Log.d(TAG, "Cancelled alarm for id=$id")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to cancel alarm id=$id: ${e.message}")
        }
    }

    fun rescheduleNextIfNeeded(context: Context, id: Int, payload: String) {
        if (payload.isEmpty()) return
        val parts = payload.split('|')
        if (parts.size < 10) return

        val isEscalation = parts.size > 5 && parts[5] == "1"
        if (isEscalation) return

        val frequency = parts[7]
        val hour = parts[8].toIntOrNull() ?: return
        val minute = parts[9].toIntOrNull() ?: return
        val dayOfWeek = if (parts.size > 10) parts[10].toIntOrNull() else null

        val now = System.currentTimeMillis()

        if (frequency == "daily") {
            val cal = Calendar.getInstance().apply {
                timeInMillis = now
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                if (timeInMillis <= now + 5000) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }
            Log.d(TAG, "Rescheduling daily alarm id=$id for next occurrence: ${cal.time}")
            schedule(context, id, cal.timeInMillis, payload)
        } else if (frequency == "specificDays" && dayOfWeek != null) {
            val targetCalendarDay = when (dayOfWeek) {
                1 -> Calendar.MONDAY
                2 -> Calendar.TUESDAY
                3 -> Calendar.WEDNESDAY
                4 -> Calendar.THURSDAY
                5 -> Calendar.FRIDAY
                6 -> Calendar.SATURDAY
                7 -> Calendar.SUNDAY
                else -> Calendar.MONDAY
            }
            val cal = Calendar.getInstance().apply {
                timeInMillis = now
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_YEAR, 1)
                while (get(Calendar.DAY_OF_WEEK) != targetCalendarDay) {
                    add(Calendar.DAY_OF_YEAR, 1)
                }
            }
            Log.d(TAG, "Rescheduling specificDays alarm id=$id (day $dayOfWeek) for next occurrence: ${cal.time}")
            schedule(context, id, cal.timeInMillis, payload)
        }
    }

    private fun saveAlarmToPrefs(context: Context, id: Int, triggerAtMillis: Long, payload: String) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putString("alarm_$id", "$triggerAtMillis|$payload").apply()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to save alarm to prefs: ${e.message}")
        }
    }

    private fun removeAlarmFromPrefs(context: Context, id: Int) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().remove("alarm_$id").apply()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to remove alarm from prefs: ${e.message}")
        }
    }

    fun restoreAlarmsOnBoot(context: Context) {
        try {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val keys = prefs.all.keys
            val now = System.currentTimeMillis()

            for (key in keys) {
                if (!key.startsWith("alarm_")) continue
                val idStr = key.removePrefix("alarm_")
                val id = idStr.toIntOrNull() ?: continue
                val value = prefs.getString(key, null) ?: continue
                val firstPipe = value.indexOf('|')
                if (firstPipe == -1) continue

                val triggerAtMillis = value.substring(0, firstPipe).toLongOrNull() ?: continue
                val payload = value.substring(firstPipe + 1)

                val parts = payload.split('|')
                val frequency = if (parts.size > 7) parts[7] else "daily"

                if (frequency == "once") {
                    if (triggerAtMillis > now) {
                        schedule(context, id, triggerAtMillis, payload)
                    } else {
                        removeAlarmFromPrefs(context, id)
                    }
                } else {
                    if (triggerAtMillis > now) {
                        schedule(context, id, triggerAtMillis, payload)
                    } else {
                        rescheduleNextIfNeeded(context, id, payload)
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore alarms on boot: ${e.message}")
        }
    }
}

