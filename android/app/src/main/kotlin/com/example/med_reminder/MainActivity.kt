package com.example.med_reminder

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        const val ALARM_CHANNEL = "com.example.med_reminder/alarm"
        const val ACTION_OPEN_ALARM_SCREEN = "OPEN_ALARM_SCREEN"
    }

    private var alarmMethodChannel: MethodChannel? = null
    private var pendingAlarmPayload: String? = null

    private fun setAlarmLockScreenBypass(enabled: Boolean) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(enabled)
                setTurnScreenOn(enabled)
            }
            if (enabled) {
                @Suppress("DEPRECATION")
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            } else {
                @Suppress("DEPRECATION")
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
                )
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error setting lock screen bypass: ${e.message}")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        alarmMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL
        )

        alarmMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val triggerAtMillis = (call.argument<Number>("triggerAtMillis") ?: 0L).toLong()
                    val payload = call.argument<String>("payload") ?: ""
                    AlarmScheduler.schedule(applicationContext, id, triggerAtMillis, payload)
                    result.success(null)
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    AlarmScheduler.cancel(applicationContext, id)
                    result.success(null)
                }
                "getInitialAlarmPayload" -> {
                    val payload = pendingAlarmPayload
                    pendingAlarmPayload = null
                    result.success(payload)
                }
                "stopAlarmSound" -> {
                    AlarmService.stopAlarm(applicationContext)
                    result.success(null)
                }
                "enableAlarmLockScreenBypass" -> {
                    setAlarmLockScreenBypass(true)
                    result.success(null)
                }
                "dismissAlarmScreen" -> {
                    // 1. Stop native alarm sound, vibration & foreground service
                    AlarmService.stopAlarm(applicationContext)
                    // 2. Clear lockscreen bypass flags
                    setAlarmLockScreenBypass(false)
                    // 3. Send task to back to return to the previously active app or lock screen
                    window.decorView.post {
                        moveTaskToBack(true)
                    }
                    result.success(null)
                }
                "hasIgnoreBatteryOptimizations" -> {
                    val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                "requestIgnoreBatteryOptimizations" -> {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(null)
                }
                "requestDisableAutoRevoke" -> {
                    try {
                        val intent = Intent(
                            Intent.ACTION_AUTO_REVOKE_PERMISSIONS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    } catch (e: Exception) {
                        val intent = Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")
                        )
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(applicationContext))
                }
                "requestOverlayPermission" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:$packageName")
                    )
                    startActivity(intent)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Process any cold start intent
        consumeAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        consumeAlarmIntent(intent)
    }

    private fun consumeAlarmIntent(intent: Intent?) {
        if (intent == null) return

        val payload = extractPayload(intent)
        if (!payload.isNullOrEmpty()) {
            Log.d(TAG, "consumeAlarmIntent found payload: $payload")
            setAlarmLockScreenBypass(true)
            pendingAlarmPayload = payload
            alarmMethodChannel?.invokeMethod("onAlarmLaunch", payload)
        }
    }

    private fun extractPayload(intent: Intent): String? {
        val p1 = intent.getStringExtra("payload")
        if (!p1.isNullOrEmpty()) return p1

        val p2 = intent.getStringExtra("notification_payload")
        if (!p2.isNullOrEmpty()) return p2

        val extras = intent.extras
        if (extras != null) {
            val ep1 = extras.getString("payload")
            if (!ep1.isNullOrEmpty()) return ep1
            val ep2 = extras.getString("notification_payload")
            if (!ep2.isNullOrEmpty()) return ep2
        }
        return null
    }
}