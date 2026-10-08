package com.war2aty.app

import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        removeSystemSplashExitAnimation()
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
