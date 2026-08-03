package com.example.med_reminder

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val ALARM_CHANNEL = "com.example.med_reminder/alarm"
        const val ACTION_OPEN_ALARM_SCREEN = "OPEN_ALARM_SCREEN"
    }

    private var alarmMethodChannel: MethodChannel? = null

    // Set when AlarmService cold-launches this Activity (app was fully
    // killed) - the engine has JUST attached and Dart's listener may not
    // be wired up yet, so we stash the payload here instead of firing
    // invokeMethod blind. Dart explicitly pulls it via
    // "getInitialAlarmPayload" once it's ready to receive it.
    private var pendingAlarmPayload: String? = null

    // Whether to draw over the lock screen (and turn the screen on) must be
    // scoped to ONLY the moment an alarm is actually being shown - not a
    // permanent property of this Activity. If this were declared instead
    // via android:showWhenLocked/android:turnScreenOn on the <activity> tag
    // in AndroidManifest.xml, it would apply for the Activity's entire
    // lifetime, meaning EVERY normal resume (e.g. pressing the power button
    // to wake the phone with the app already open) skips the lock screen
    // entirely - not just alarm launches. Applying and clearing it here
    // instead keeps the bypass limited to genuine alarm events.
    private fun setAlarmLockScreenBypass(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enabled)
            setTurnScreenOn(enabled)
        } else {
            if (enabled) {
                window.addFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            } else {
                window.clearFlags(
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                )
            }
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
                    result.success(pendingAlarmPayload)
                    pendingAlarmPayload = null
                }
                "enableAlarmLockScreenBypass" -> {
                    // Covers the path AlarmService intentionally skips: when
                    // the screen is locked, flutter_local_notifications'
                    // full-screen intent is what launches this Activity -
                    // via its own default launch intent, NOT
                    // ACTION_OPEN_ALARM_SCREEN. That means
                    // consumeColdStartAlarmIntent()/onNewIntent() never see
                    // it and never apply the bypass, so the Activity ends up
                    // rendering (with sound already playing) behind the
                    // keyguard instead of over it. Dart calls this the
                    // moment it knows a genuine alarm response came in -
                    // from onDidReceiveNotificationResponse - regardless of
                    // which of the three trigger paths caused it, so it's
                    // safe/redundant-but-harmless for the native path too.
                    setAlarmLockScreenBypass(true)
                    result.success(null)
                }
                "dismissAlarmScreen" -> {
                    // Called from AlarmRingScreen instead of Navigator.pop().
                    // Sends this whole task to the back so the OS reveals
                    // whatever app/screen was in front before the alarm
                    // interrupted it (e.g. another app, or the lock screen),
                    // rather than exposing our own HomeScreen underneath.
                    //
                    // Must ALSO turn the lock-screen bypass back off here -
                    // this same Activity instance keeps living (singleTop/
                    // reordered-to-front, not recreated), so if the flags
                    // set in setAlarmLockScreenBypass(true) were never
                    // cleared, every future normal resume of the app would
                    // keep skipping the lock screen too.
                    setAlarmLockScreenBypass(false)
                    // setShowWhenLocked(false) only registers the request;
                    // the window manager needs an actual layout pass to act
                    // on it and let the real system keyguard - which was
                    // only ever occluded, never dismissed, for a secure
                    // lock - reassert itself as the topmost window. Calling
                    // moveTaskToBack() synchronously right after risks
                    // beating that layout pass: this task can lose focus
                    // before the OS has re-checked whether it's still
                    // allowed to skip the keyguard, briefly revealing
                    // whatever this task's own content is (the Flutter
                    // HomeScreen sitting underneath AlarmRingScreen) instead
                    // of the real lock screen. Posting to the next frame
                    // gives the flag change time to land first.
                    window.decorView.post {
                        moveTaskToBack(true)
                    }
                    result.success(null)
                }
                "hasOverlayPermission" -> {
                    // Required for AlarmService to draw AlarmRingScreen over
                    // whatever app is currently in the foreground. Without
                    // this, Android 10+ silently blocks the direct-launch
                    // and only the notification banner shows.
                    result.success(Settings.canDrawOverlays(applicationContext))
                }
                "requestOverlayPermission" -> {
                    // Cannot be granted programmatically - this opens the
                    // system settings screen where the user must toggle it
                    // on manually. There is no permission-request dialog
                    // for SYSTEM_ALERT_WINDOW, unlike runtime permissions.
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

        // Cold-start case: this Activity may have just been created BY
        // AlarmService's direct-launch intent (app was fully killed).
        consumeColdStartAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)

        // Warm case: app was already running (foreground or background)
        // when AlarmService launched us - the engine + channel already
        // exist, so push straight through to Dart.
        if (intent.action == ACTION_OPEN_ALARM_SCREEN) {
            setAlarmLockScreenBypass(true)
            val payload = intent.getStringExtra("payload")
            alarmMethodChannel?.invokeMethod("onAlarmLaunch", payload)
        }
    }

    private fun consumeColdStartAlarmIntent(intent: Intent?) {
        if (intent?.action == ACTION_OPEN_ALARM_SCREEN) {
            setAlarmLockScreenBypass(true)
            pendingAlarmPayload = intent.getStringExtra("payload")
        }
    }
}