package com.believoo.app

import android.app.PictureInPictureParams
import android.content.res.Configuration
import android.content.res.Resources
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.util.Rational
import android.view.Window
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val DEBUG_CHANNEL = "com.believoo.app/debug"
    private val SYSTEM_CHANNEL = "com.believoo.app/system"
    private val LIVE_PIP_CHANNEL = "com.believoo.app/live_pip"
    private var autoPipEnabled = false
    private var livePipChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        applyWindowInsets()
        applyInitialColors()
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun onResume() {
        super.onResume()
        // Re-apply insets only so Dart-set colors are not overwritten.
        applyWindowInsets()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        livePipChannel?.invokeMethod(
            "pipModeChanged",
            mapOf("isInPipMode" to isInPictureInPictureMode)
        )
    }

    override fun onUserLeaveHint() {
        if (autoPipEnabled) enterPipMode()
        super.onUserLeaveHint()
    }

    private fun enterPipMode(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || isInPictureInPictureMode) return false
        return try {
            val params = PictureInPictureParams.Builder()
                .setAspectRatio(Rational(9, 16))
                .build()
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            Log.w("BELIVE_NATIVE", "Unable to enter PiP: $e")
            false
        }
    }

    /// Reads the Android framework resource that tells us which navigation
    /// interaction mode the device is using:
    ///   0 = 3-button, 1 = 2-button, 2 = gesture.
    ///
    /// Falls back to threeButton on older Android versions where the resource
    /// does not exist, because pre-Android-10 devices almost always use a
    /// software 3-button nav bar.
    private fun getNavigationMode(): String {
        return try {
            val resId = Resources.getSystem().getIdentifier(
                "config_navBarInteractionMode",
                "integer",
                "android"
            )
            if (resId != 0) {
                when (Resources.getSystem().getInteger(resId)) {
                    0 -> "threeButton"
                    1 -> "twoButton"
                    2 -> "gesture"
                    else -> "unknown"
                }
            } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                "threeButton"
            } else {
                "unknown"
            }
        } catch (e: Exception) {
            Log.w("BELIVE_NATIVE", "getNavigationMode failed: $e")
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) "threeButton" else "unknown"
        }
    }

    /// Re-apply the window insets and cutout handling. This only touches
    /// geometry flags, not colors, so Dart's [SystemUiService] can keep full
    /// control of status/navigation bar colors.
    private fun applyWindowInsets() {
        val window: Window = window

        // Allow content to flow into display cutouts / notches.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }

        // We need to draw the system bar backgrounds ourselves.
        window.addFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS)

        // Always run edge-to-edge. Flutter will draw behind both status and
        // navigation bars; the Dart side adds bottom padding when a visible
        // 3-button navigation bar is present, and sets a solid nav color.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    /// Initial colors before Dart has a chance to set them. For 3-button nav
    /// we leave a solid black navigation bar; for gesture/hidden we go
    /// transparent so the app can be full screen.
    @Suppress("DEPRECATION")
    private fun applyInitialColors() {
        val window: Window = window
        val useEdgeToEdge = when (getNavigationMode()) {
            "twoButton", "threeButton" -> false
            else -> true
        }

        if (useEdgeToEdge) {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            window.navigationBarColor = android.graphics.Color.TRANSPARENT
        } else {
            window.statusBarColor = android.graphics.Color.TRANSPARENT
            // Start with a white nav bar; Dart's SystemUiService will replace
            // it with the exact app background color once the app is ready.
            window.navigationBarColor = android.graphics.Color.WHITE
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        Log.d("BELIVE_NATIVE", "configureFlutterEngine START")
        try {
            super.configureFlutterEngine(flutterEngine)
            Log.d("BELIVE_NATIVE", "configureFlutterEngine SUCCESS (Plugins registered)")
        } catch (e: Exception) {
            Log.e("BELIVE_NATIVE", "configureFlutterEngine FAILED", e)
        }

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        livePipChannel = MethodChannel(messenger, LIVE_PIP_CHANNEL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setAutoPip" -> {
                        autoPipEnabled = call.argument<Boolean>("enabled") ?: false
                        result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    }
                    "isInPipMode" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode
                    )
                    else -> result.notImplemented()
                }
            }
        }

        MethodChannel(messenger, DEBUG_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "log" -> {
                    val msg = call.argument<String>("msg") ?: ""
                    Log.d("BELIVE_DART", msg)
                    result.success(null)
                }
                "setSecureFlag" -> {
                    // Prevent screen recording / screenshots (FLAG_SECURE)
                    val secure = call.argument<Boolean>("secure") ?: false
                    runOnUiThread {
                        if (secure) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                    }
                    result.success(null)
                }
                "setAutoPip" -> {
                    autoPipEnabled = call.argument<Boolean>("enabled") ?: false
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                }
                "setPipMode" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    autoPipEnabled = enabled
                    result.success(if (enabled) enterPipMode() else true)
                }
                else -> result.notImplemented()
            }
        }
        Log.d("BELIVE_NATIVE", "Debug channel registered")

        MethodChannel(messenger, SYSTEM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNavigationMode" -> {
                    result.success(getNavigationMode())
                }
                else -> result.notImplemented()
            }
        }
        Log.d("BELIVE_NATIVE", "System channel registered")
    }
}
