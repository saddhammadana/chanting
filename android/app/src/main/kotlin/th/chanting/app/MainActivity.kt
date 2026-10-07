package th.chanting.app

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.Bundle
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // With the bars hidden a window is kept out of the camera cutout by
        // default, which leaves a black band where the status bar was.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Fullscreen reading and a running sitting hide the system bars. The
        // window is asked directly: Flutter's SystemChrome modes also switch
        // how the window fits the bars, and coming back from immersive left
        // the status bar as an empty black band on some phones.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "th.chanting.app/system_bars")
            .setMethodCallHandler { call, result ->
                if (call.method == "setHidden") {
                    setSystemBarsHidden(call.argument<Boolean>("hidden") == true)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        // Flutter's HapticFeedback is touch feedback: it obeys the system's
        // "touch vibration" switch and is silent on phones that have it off.
        // The completion signal needs the vibrator itself.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "th.chanting.app/vibrate")
            .setMethodCallHandler { call, result ->
                if (call.method == "vibrate") {
                    vibrate((call.argument<Int>("ms") ?: 250).toLong())
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    @Suppress("DEPRECATION")
    private fun setSystemBarsHidden(hidden: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            if (hidden) {
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
                controller.hide(WindowInsets.Type.systemBars())
            } else {
                controller.show(WindowInsets.Type.systemBars())
            }
            return
        }
        // Before Android 11 the view flags are the only API there is.
        val layout = View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
            View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
            View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
        window.decorView.systemUiVisibility = if (hidden) {
            layout or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_FULLSCREEN
        } else {
            layout
        }
    }

    @Suppress("DEPRECATION")
    private fun vibrate(ms: Long) {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
        if (!vibrator.hasVibrator()) return
        // Alarm usage: a sitting ending is something the user asked to be told
        // about, so it should not be dropped with touch or media haptics.
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU -> vibrator.vibrate(
                VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE),
                VibrationAttributes.createForUsage(VibrationAttributes.USAGE_ALARM),
            )
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O -> vibrator.vibrate(
                VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).build(),
            )
            else -> vibrator.vibrate(ms)
        }
    }
}
