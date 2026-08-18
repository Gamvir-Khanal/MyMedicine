package com.example.med_reminder

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.util.Log
import java.io.File

object AlarmSoundPlayer {
    private const val TAG = "AlarmSoundPlayer"
    private var mediaPlayer: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    @Synchronized
    fun start(context: Context, customSoundPath: String? = null) {
        stop()

        try {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .apply {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        setAllowedCapturePolicy(AudioAttributes.ALLOW_CAPTURE_BY_NONE)
                    }
                }
                .build()

            val player = MediaPlayer().apply {
                setAudioAttributes(audioAttributes)
                setAudioStreamType(AudioManager.STREAM_ALARM)
                isLooping = true
            }

            var prepared = false

            if (!customSoundPath.isNullOrEmpty()) {
                val soundFile = File(customSoundPath)
                if (soundFile.exists() && soundFile.canRead()) {
                    try {
                        player.setDataSource(context, Uri.fromFile(soundFile))
                        player.prepare()
                        prepared = true
                        Log.d(TAG, "Playing custom sound from $customSoundPath")
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to prepare custom sound, falling back: ${e.message}")
                        player.reset()
                        player.setAudioAttributes(audioAttributes)
                    }
                }
            }

            if (!prepared) {
                try {
                    val rawUri = Uri.parse("android.resource://${context.packageName}/${R.raw.alarm_tone}")
                    player.setDataSource(context, rawUri)
                    player.prepare()
                    prepared = true
                    Log.d(TAG, "Playing bundled raw alarm_tone.mp3")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to play raw alarm_tone, falling back to system alarm: ${e.message}")
                    player.reset()
                    player.setAudioAttributes(audioAttributes)
                }
            }

            if (!prepared) {
                try {
                    val alertUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    player.setDataSource(context, alertUri)
                    player.prepare()
                    prepared = true
                    Log.d(TAG, "Playing system alarm/notification tone")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to prepare system alarm tone: ${e.message}")
                }
            }

            if (prepared) {
                player.setVolume(1.0f, 1.0f)
                player.start()
                mediaPlayer = player
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting alarm sound: ${e.message}", e)
        }

        try {
            val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vibratorManager = context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
                vibratorManager?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }

            vib?.let { v ->
                if (v.hasVibrator()) {
                    val pattern = longArrayOf(0, 800, 400, 800, 400)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val effect = VibrationEffect.createWaveform(pattern, 0)
                        val audioAttributes = AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ALARM)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .build()
                        v.vibrate(effect, audioAttributes)
                    } else {
                        @Suppress("DEPRECATION")
                        v.vibrate(pattern, 0)
                    }
                    vibrator = v
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting vibration: ${e.message}")
        }
    }

    @Synchronized
    fun stop() {
        try {
            mediaPlayer?.let {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping media player: ${e.message}")
        } finally {
            mediaPlayer = null
        }

        try {
            vibrator?.cancel()
        } catch (e: Exception) {
            Log.w(TAG, "Error stopping vibrator: ${e.message}")
        } finally {
            vibrator = null
        }
    }
}
