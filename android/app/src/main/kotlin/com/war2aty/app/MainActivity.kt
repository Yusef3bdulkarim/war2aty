package com.war2aty.app

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** Must match the channel name in `MethodChannelSystemTtsSettings`. */
    private val systemSettingsChannel = "com.war2aty.app/system_settings"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        removeSystemSplashExitAnimation()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            systemSettingsChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canOpenTtsSettings" -> result.success(resolveTtsSettings() != null)
                "openTtsSettings" -> result.success(openTtsSettings())
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Opens Android's own text-to-speech settings, where a reading voice can
     * be installed or switched (F30-T07).
     *
     * The app needs this because a phone whose engine ships no Arabic voice
     * cannot read an Arabic paper at all, and telling the user that without
     * giving them a way to fix it would leave them stuck. Deliberately a
     * channel of our own rather than an intent plugin: it is one intent, and
     * this project adds no dependency it can avoid — the same reasoning
     * [removeSystemSplashExitAnimation] records for the splash API.
     *
     * Answers false rather than throwing when no activity can handle the
     * intent, which the Dart side reports as "nothing to open" so the message
     * stays on screen without a button that does nothing.
     */
    private fun openTtsSettings(): Boolean {
        val intent = resolveTtsSettings() ?: return false
        return try {
            startActivity(intent)
            true
        } catch (notFound: ActivityNotFoundException) {
            false
        }
    }

    /**
     * The intent that reaches a screen where a reading voice can be
     * installed, or null when this build has none.
     *
     * Asked before the sheet is shown as well as when its button is tapped,
     * so the app never offers «افتح إعدادات الموبايل» on a phone where it
     * would do nothing.
     *
     * The text-to-speech screen first — it is the exact place the user needs
     * — and the accessibility settings as a fallback, since some builds do
     * not register the TTS screen on its own but always reach it from there.
     */
    private fun resolveTtsSettings(): Intent? {
        // There is no public Settings.ACTION_* constant for the TTS screen,
        // so the action is the string the Settings app registers for it.
        val candidates = listOf(
            Intent("com.android.settings.TTS_SETTINGS"),
            Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
        )
        return candidates
            .firstOrNull { it.resolveActivity(packageManager) != null }
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    /**
     * Takes the Android 12+ system splash off screen the instant Flutter has
     * drawn, with no exit animation of its own (F28-T05).
     *
     * The system splash does not simply disappear when the app draws: by
     * default it plays the icon out, fading and scaling it. Every other layer
     * of this launch was built so that the mark is in the same place at the
     * same size throughout, and that default animation would undo exactly
     * that — the mark would shrink away and Flutter's identical mark would
     * appear behind it.
     *
     * Removing the splash view immediately is correct here only because
     * Flutter's first frame is already a copy of it. The listener fires when
     * the app is ready to draw, so there is nothing to cover and nothing to
     * ease.
     *
     * Guarded on API 31, where `Activity.getSplashScreen()` arrives. Below it
     * the platform draws `launch_background.xml` and simply stops, which is
     * the behaviour this is reproducing. Deliberately the platform API rather
     * than `androidx.core:core-splashscreen`: it is three lines and no new
     * dependency.
     */
    private fun removeSystemSplashExitAnimation() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        splashScreen.setOnExitAnimationListener { splashScreenView ->
            splashScreenView.remove()
        }
    }
}
