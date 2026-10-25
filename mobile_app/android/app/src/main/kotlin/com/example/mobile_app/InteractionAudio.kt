package com.example.mobile_app

import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Small, preloaded UI cues. No audio focus, looping, delayed queue or permissions. */
class InteractionAudio(private val context: Context, messenger: BinaryMessenger) {
    private val preferences = context.getSharedPreferences("interaction_audio", Context.MODE_PRIVATE)
    private var enabled = preferences.getBoolean("enabled", true)
    private var active = false
    private var released = false
    private var stream = 0
    private var importantUntil = -1000L
    private var lastPlayAt = -1000L
    private val ready = mutableSetOf<Int>()
    private val pool = SoundPool.Builder().setMaxStreams(1).setAudioAttributes(
        AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    ).build()
    private val channel = MethodChannel(messenger, "duiqi/interaction_audio")
    private val samples: Map<String, Int>

    init {
        pool.setOnLoadCompleteListener { _, id, status -> if (!released && status == 0) ready.add(id) }
        samples = mapOf("tap" to R.raw.ui_tap, "select" to R.raw.ui_select,
            "success" to R.raw.ui_success, "failure" to R.raw.ui_failure,
            "checkinSuccess" to R.raw.ui_checkin_success,
            "transition" to R.raw.ui_transition).mapValues { (_, resource) ->
            runCatching { pool.load(context, resource, 1) }.getOrDefault(0)
        }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getEnabled" -> result.success(enabled)
                "setEnabled" -> {
                    val value = call.arguments as? Boolean
                    if (value == null) result.error("invalid_argument", "Expected a boolean", null)
                    else {
                        enabled = value
                        preferences.edit().putBoolean("enabled", value).apply()
                        if (!value) stop()
                        result.success(enabled)
                    }
                }
                "play" -> result.success(play(call.arguments as? String))
                else -> result.notImplemented()
            }
        }
    }

    fun setActive(value: Boolean) { active = value; if (!value) stop() }

    private fun play(cue: String?): Boolean {
        if (released || !active || !enabled) return false
        val id = samples[cue] ?: return false
        if (id == 0 || !ready.contains(id)) return false
        val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL ||
            notifications.currentInterruptionFilter != NotificationManager.INTERRUPTION_FILTER_ALL) return false
        val now = SystemClock.uptimeMillis()
        val important = cue == "success" || cue == "failure" || cue == "checkinSuccess"
        if (!important && (now < importantUntil || now - lastPlayAt < 35)) return false
        stop()
        stream = pool.play(id, .6f, .6f, if (important) 2 else 1, 0, 1f)
        if (stream == 0) return false
        lastPlayAt = now
        if (important) importantUntil = now + if (cue == "checkinSuccess") 1100 else 240
        return true
    }

    private fun stop() { if (!released && stream != 0) pool.stop(stream); stream = 0 }

    fun dispose() {
        if (released) return
        stop()
        released = true
        channel.setMethodCallHandler(null)
        pool.setOnLoadCompleteListener(null)
        pool.release()
        ready.clear()
    }
}
