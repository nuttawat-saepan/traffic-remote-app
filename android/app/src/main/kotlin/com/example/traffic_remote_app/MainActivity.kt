package com.example.traffic_remote_app

import android.view.View
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.example.traffic_remote_app/kiosk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKiosk" -> {
                    window.decorView.systemUiVisibility = (
                        View.SYSTEM_UI_FLAG_FULLSCREEN
                            or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    )
                    try {
                        startLockTask()
                    } catch (_: Exception) {
                        // Some devices require screen pinning or device-owner setup first.
                    }
                    result.success(null)
                }
                "stopKiosk" -> {
                    try {
                        stopLockTask()
                    } catch (_: IllegalStateException) {
                        // The app was not in lock task mode.
                    }
                    window.decorView.systemUiVisibility = View.SYSTEM_UI_FLAG_VISIBLE
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
